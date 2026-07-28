"""Unit tests for bin/bump-deps.

`bump-deps --self-test` already proves that in-place editing is surgical, but it
runs against the real repo files and cannot reach `check_invariants()` at all --
every violation branch there requires a deliberately broken tree. These tests use
a fixture repo instead (see helper.py), which makes the failure paths reachable
and keeps the real files untouched.

Anything needing the network (`gh api`, urlopen, gpg) is monkeypatched. Nothing
here requires `gh` to be installed or authenticated.
"""

from __future__ import annotations

import unittest

from helper import bump_deps, fixture_repo, pin, read

Problem = bump_deps.Problem


class CurrentValue(unittest.TestCase):
    """Reading a pin out of a file."""

    def test_reads_a_single_occurrence(self):
        with fixture_repo():
            self.assertEqual(bump_deps.current_value(pin("chezmoi")), "v2.71.1")
            self.assertEqual(bump_deps.current_value(pin("shellcheck")), "v0.11.0")
            self.assertEqual(bump_deps.current_value(pin("lazygit")), "0.58.0")

    def test_occurrences_all_accepts_repeats(self):
        # actions/checkout appears twice in the fixture CI file.
        with fixture_repo():
            self.assertEqual(bump_deps.current_value(pin("actions/checkout")), "v7.0.1")

    def test_missing_pattern_is_a_problem(self):
        with fixture_repo(**{"install.sh": "#!/bin/sh\necho nothing pinned here\n"}):
            with self.assertRaises(Problem) as ctx:
                bump_deps.current_value(pin("chezmoi"))
            self.assertIn("pattern not found", str(ctx.exception))

    def test_inconsistent_values_are_a_problem(self):
        # Two different checkout versions in one workflow: bumping either one
        # would leave the other behind, so this must abort rather than pick one.
        broken = read_fixture_ci().replace(
            "gitleaks/gitleaks-action@v3.0.0", "actions/checkout@v6.0.0"
        )
        with fixture_repo(**{".github/workflows/ci.yaml": broken}):
            with self.assertRaises(Problem) as ctx:
                bump_deps.current_value(pin("actions/checkout"))
            self.assertIn("inconsistent values", str(ctx.exception))

    def test_occurrence_count_mismatch_is_a_problem(self):
        # This guard is what stops a silent edit of the wrong number of lines.
        doubled = read_fixture_ci().replace(
            "          SHELLCHECK_VERSION: v0.11.0",
            "          SHELLCHECK_VERSION: v0.11.0\n          SHELLCHECK_VERSION: v0.11.0",
        )
        with fixture_repo(**{".github/workflows/ci.yaml": doubled}):
            with self.assertRaises(Problem) as ctx:
                bump_deps.current_value(pin("shellcheck"))
            self.assertIn("expected 1 occurrence(s)", str(ctx.exception))


class ReplaceValue(unittest.TestCase):
    """Rewriting a pin in place."""

    def test_rewrites_only_the_capture_group(self):
        with fixture_repo() as repo:
            n = bump_deps.replace_value(pin("chezmoi"), "v2.71.1", "v2.72.0")
            self.assertEqual(n, 1)
            text = read(repo, "install.sh")
            self.assertIn('CHEZMOI_VERSION="v2.72.0"', text)
            # Surrounding syntax survives intact.
            self.assertIn("#!/bin/sh", text)
            self.assertIn('echo "installing ${CHEZMOI_VERSION}"', text)

    def test_does_not_touch_the_same_literal_elsewhere_on_the_line(self):
        # bump-deps rebuilds the matched text instead of substituting blind. This
        # is the case that distinguishes the two: a naive re.sub over the whole
        # line would rewrite the comment as well.
        tricky = (
            "#!/bin/sh\n"
            'CHEZMOI_VERSION="v2.71.1"  # keep v2.71.1 in this comment\n'
        )
        with fixture_repo(**{"install.sh": tricky}) as repo:
            bump_deps.replace_value(pin("chezmoi"), "v2.71.1", "v2.72.0")
            line = read(repo, "install.sh").splitlines()[1]
            self.assertEqual(
                line, 'CHEZMOI_VERSION="v2.72.0"  # keep v2.71.1 in this comment'
            )

    def test_rewrites_the_capture_group_only_once_within_a_match(self):
        # replace_value bounds its inner replace to 1. No pin in the registry today
        # has a pattern whose match contains the pinned value twice, so this is the
        # only place that bound is observable -- which is exactly why it is worth
        # writing down. A pattern spanning "value ... same value again" must rewrite
        # the capture group and leave the rest of the match alone.
        synthetic = {
            "name": "synthetic",
            "file": "install.sh",
            "pattern": r'CHEZMOI_VERSION="([^"]+)"  # pinned to \S+',
            "occurrences": 1,
        }
        text = '#!/bin/sh\nCHEZMOI_VERSION="v2.71.1"  # pinned to v2.71.1\n'
        with fixture_repo(**{"install.sh": text}) as repo:
            bump_deps.replace_value(synthetic, "v2.71.1", "v2.72.0")
            line = read(repo, "install.sh").splitlines()[1]
        self.assertEqual(line, 'CHEZMOI_VERSION="v2.72.0"  # pinned to v2.71.1')

    def test_replaces_every_occurrence_for_all_pins(self):
        with fixture_repo() as repo:
            n = bump_deps.replace_value(pin("actions/checkout"), "v7.0.1", "v8.0.0")
            self.assertEqual(n, 2)
            self.assertNotIn("v7.0.1", read(repo, ".github/workflows/ci.yaml"))

    def test_line_count_never_changes(self):
        with fixture_repo() as repo:
            before = read(repo, ".github/workflows/ci.yaml").count("\n")
            bump_deps.replace_value(pin("shellcheck"), "v0.11.0", "v0.12.0")
            after = read(repo, ".github/workflows/ci.yaml").count("\n")
            self.assertEqual(before, after)

    def test_nothing_to_replace_is_a_problem(self):
        with fixture_repo(**{"install.sh": "#!/bin/sh\n"}):
            with self.assertRaises(Problem):
                bump_deps.replace_value(pin("chezmoi"), "v2.71.1", "v2.72.0")


class ParseExternals(unittest.TestCase):
    """Line-oriented parsing of .chezmoiexternal.yaml."""

    def test_parses_both_kinds(self):
        with fixture_repo():
            exts = bump_deps.parse_externals()
        kinds = [e["kind"] for e in exts]
        self.assertEqual(kinds, ["file", "archive", "archive"])
        self.assertEqual(exts[0]["repo"], "junegunn/vim-plug")
        self.assertEqual(exts[0]["ref"], "0.14.0")
        self.assertEqual(exts[0]["asset"], "plug.vim")
        self.assertEqual(exts[1]["repo"], "sindresorhus/pure")
        self.assertEqual(exts[1]["ref"], "1" * 40)

    def test_archive_entries_find_their_orientation_comment(self):
        with fixture_repo():
            exts = bump_deps.parse_externals()
        self.assertIsNotNone(exts[1]["comment_line"])
        # A raw-file entry has no "repo @ date" comment above it.
        self.assertIsNone(exts[0]["comment_line"])

    def test_comment_line_is_none_when_there_is_no_dated_comment(self):
        no_comment = FIXTURE_EXTERNALS.replace(
            "# sindresorhus/pure @ 2026-07-16 (nearest tag: v1.28.3)\n", ""
        )
        with fixture_repo(**{".chezmoiexternal.yaml": no_comment}):
            exts = bump_deps.parse_externals()
        pure = next(e for e in exts if e["repo"] == "sindresorhus/pure")
        self.assertIsNone(pure["comment_line"])

    def test_a_checksum_too_far_away_is_a_problem(self):
        # The sha256 must be within 8 lines of its url, or the parser could pair a
        # url with some other entry's checksum -- which would defeat the pinning.
        padded = FIXTURE_EXTERNALS.replace(
            '    exact: true\n    stripComponents: 1\n    checksum:\n'
            '        sha256: "' + "b" * 64 + '"\n',
            "    exact: true\n" + "    # filler\n" * 9 + '    checksum:\n'
            '        sha256: "' + "b" * 64 + '"\n',
            1,
        )
        with fixture_repo(**{".chezmoiexternal.yaml": padded}):
            with self.assertRaises(Problem) as ctx:
                bump_deps.parse_externals()
            self.assertIn("no sha256 within 8 lines", str(ctx.exception))


class BumpExternal(unittest.TestCase):
    """Editing .chezmoiexternal.yaml without disturbing its comments."""

    def test_rewrites_ref_checksum_and_comment(self):
        with fixture_repo() as repo:
            ext = next(
                e for e in bump_deps.parse_externals() if e["repo"] == "sindresorhus/pure"
            )
            bump_deps.bump_external(ext, "3" * 40, "d" * 64, "2027-01-02", "v2.0.0")
            text = read(repo, ".chezmoiexternal.yaml")

        self.assertIn("3" * 40, text)
        self.assertIn("d" * 64, text)
        self.assertIn("# sindresorhus/pure @ 2027-01-02 (nearest tag: v2.0.0)", text)
        self.assertNotIn("1" * 40, text)

    def test_preserves_every_other_line(self):
        # The reason a YAML library is deliberately not used: load/dump would erase
        # the comments that explain why each entry is pinned.
        with fixture_repo() as repo:
            before = read(repo, ".chezmoiexternal.yaml").splitlines()
            ext = next(
                e for e in bump_deps.parse_externals() if e["repo"] == "sindresorhus/pure"
            )
            bump_deps.bump_external(ext, "3" * 40, "d" * 64, "2027-01-02", "v2.0.0")
            after = read(repo, ".chezmoiexternal.yaml").splitlines()

        self.assertEqual(len(before), len(after))
        changed = [i for i, (a, b) in enumerate(zip(before, after)) if a != b]
        # Exactly three lines: the url, the checksum, and the orientation comment.
        self.assertEqual(len(changed), 3, f"changed lines: {changed}")

        # Every header comment is still there, byte for byte.
        for line in before:
            if line.startswith("#") and "sindresorhus/pure @" not in line:
                self.assertIn(line, after)

    def test_leaves_other_entries_alone(self):
        with fixture_repo() as repo:
            ext = next(
                e for e in bump_deps.parse_externals() if e["repo"] == "sindresorhus/pure"
            )
            bump_deps.bump_external(ext, "3" * 40, "d" * 64, "2027-01-02", "v2.0.0")
            text = read(repo, ".chezmoiexternal.yaml")
        self.assertIn("2" * 40, text)  # zsh-z untouched
        self.assertIn("c" * 64, text)

    def test_an_unexpected_old_value_is_a_problem(self):
        with fixture_repo():
            ext = next(
                e for e in bump_deps.parse_externals() if e["repo"] == "sindresorhus/pure"
            )
            ext["ref"] = "9" * 40  # not what is actually on that line
            with self.assertRaises(Problem):
                bump_deps.bump_external(ext, "3" * 40, "d" * 64, "2027-01-02", "")

    def test_omitting_the_tag_omits_the_parenthetical(self):
        with fixture_repo() as repo:
            ext = next(
                e for e in bump_deps.parse_externals() if e["repo"] == "sindresorhus/pure"
            )
            bump_deps.bump_external(ext, "3" * 40, "d" * 64, "2027-01-02", "")
            text = read(repo, ".chezmoiexternal.yaml")
        self.assertIn("# sindresorhus/pure @ 2027-01-02\n", text)
        self.assertNotIn("nearest tag: )", text)


class CheckInvariants(unittest.TestCase):
    """The cross-file assertions. None of these is reachable without a broken tree."""

    def test_a_clean_tree_has_no_problems(self):
        with fixture_repo():
            self.assertEqual(bump_deps.check_invariants(), [])

    def test_floor_above_the_bootstrapped_version_is_caught(self):
        # The consequence if this ever ships: a fresh machine installs chezmoi and
        # is immediately refused by it, with no obvious way out.
        with fixture_repo(**{".chezmoiversion": "v2.99.0\n"}):
            problems = bump_deps.check_invariants()
        self.assertEqual(len(problems), 1)
        self.assertIn("exceeds install.sh CHEZMOI_VERSION", problems[0])

    def test_floor_equal_to_the_bootstrapped_version_is_fine(self):
        with fixture_repo(**{".chezmoiversion": "v2.71.1\n"}):
            self.assertEqual(bump_deps.check_invariants(), [])

    def test_floor_below_the_bootstrapped_version_is_fine(self):
        with fixture_repo(**{".chezmoiversion": "v2.0.0\n"}):
            self.assertEqual(bump_deps.check_invariants(), [])

    def test_version_comparison_is_numeric_not_lexical(self):
        # 2.71.10 > 2.71.9 numerically but "2.71.10" < "2.71.9" as a string. A
        # string compare here would pass a genuinely broken tree.
        install = FIXTURE_INSTALL.replace("v2.71.1", "v2.71.9")
        with fixture_repo(**{".chezmoiversion": "v2.71.10\n", "install.sh": install}):
            problems = bump_deps.check_invariants()
        self.assertEqual(len(problems), 1, "2.71.10 > 2.71.9 was not detected")
        self.assertIn("exceeds", problems[0])

    def test_a_url_without_a_checksum_is_caught(self):
        extra = FIXTURE_EXTERNALS + (
            '\n".local/zsh-plugins/unchecked":\n'
            "    type: \"archive\"\n"
            '    url: "https://github.com/someone/thing/archive/'
            + "4" * 40
            + '.tar.gz"\n'
        )
        with fixture_repo(**{".chezmoiexternal.yaml": extra}):
            problems = bump_deps.check_invariants()
        self.assertTrue(
            any("every external must have both" in p for p in problems), problems
        )

    def test_tracking_master_is_caught(self):
        moving = FIXTURE_EXTERNALS.replace("1" * 40 + ".tar.gz", "master.tar.gz")
        with fixture_repo(**{".chezmoiexternal.yaml": moving}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("moving ref" in p for p in problems), problems)

    def test_tracking_head_is_caught(self):
        moving = FIXTURE_EXTERNALS.replace("/vim-plug/0.14.0/", "/vim-plug/HEAD/")
        with fixture_repo(**{".chezmoiexternal.yaml": moving}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("moving ref" in p for p in problems), problems)

    def test_an_action_on_a_floating_major_tag_is_caught(self):
        floating = FIXTURE_CI.replace("actions/checkout@v7.0.1", "actions/checkout@v7")
        with fixture_repo(**{".github/workflows/ci.yaml": floating}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("floating tag" in p for p in problems), problems)

    def test_a_gitleaks_action_on_a_floating_tag_is_caught(self):
        floating = FIXTURE_CI.replace("gitleaks-action@v3.0.0", "gitleaks-action@v3")
        with fixture_repo(**{".github/workflows/ci.yaml": floating}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("floating tag" in p for p in problems), problems)

    def test_an_action_pinned_to_a_commit_sha_is_reported(self):
        # A 40-char SHA is arguably the strongest pin of all, but it does not match
        # the vX.Y.Z shape the check demands. Documented here so the behavior is a
        # decision on record rather than a surprise the first time someone tries it.
        sha_pinned = FIXTURE_CI.replace("actions/checkout@v7.0.1", "actions/checkout@" + "a" * 40)
        with fixture_repo(**{".github/workflows/ci.yaml": sha_pinned}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("floating tag" in p for p in problems), problems)


class Report(unittest.TestCase):
    """gather() and the --check contract with .github/workflows/deps.yaml."""

    def setUp(self):
        # Nothing may touch the network. Each test overrides what it needs.
        self._saved = {
            name: getattr(bump_deps, name)
            for name in ("gh_text", "sha256_of_url", "gpg_fingerprint")
        }
        bump_deps.gh_text = lambda *a, **k: self.fail("unexpected gh api call")
        bump_deps.sha256_of_url = lambda url: "0" * 64
        bump_deps.gpg_fingerprint = lambda url: "A" * 40

    def tearDown(self):
        for name, fn in self._saved.items():
            setattr(bump_deps, name, fn)

    def _stub_github(self, latest=None, head=None, tag=None, ahead=0):
        """Default to "upstream is exactly what the fixture pins", so a test only
        has to describe the one thing it wants to be different."""
        latest = latest or {}
        bump_deps.latest_release = lambda repo: latest.get(repo, current_tag(repo))
        bump_deps.head_sha = lambda repo: head or FIXTURE_HEADS[repo]
        bump_deps.nearest_tag = lambda repo: tag if tag is not None else "0.14.0"
        bump_deps.ahead_by = lambda repo, sha: ahead

    def test_everything_current_is_reported_as_current(self):
        self._stub_github()
        with fixture_repo():
            rows = bump_deps.gather(set())
        actionable = [r for r in rows if r.actionable]
        self.assertEqual(actionable, [], [(r.name, r.status) for r in actionable])

    def test_a_stale_version_pin_is_flagged(self):
        self._stub_github(latest={"twpayne/chezmoi": "v2.99.0"})
        with fixture_repo():
            rows = bump_deps.gather({"chezmoi"})
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].status, "stale")
        self.assertEqual(rows[0].latest, "v2.99.0")
        self.assertTrue(rows[0].actionable)

    def test_strip_v_is_applied_only_where_declared(self):
        # lazygit stores 0.58.0 while upstream tags v0.58.0. Without strip_v the
        # pin would look permanently stale and get "bumped" to an invalid value.
        self._stub_github(latest={"jesseduffield/lazygit": "v0.58.0"})
        with fixture_repo():
            rows = bump_deps.gather({"lazygit"})
        self.assertEqual(rows[0].latest, "0.58.0")
        self.assertEqual(rows[0].status, "current")

    def test_an_external_behind_head_is_flagged(self):
        self._stub_github(head="9" * 40, ahead=7)
        with fixture_repo():
            rows = bump_deps.gather({"pure"})
        self.assertEqual(rows[0].klass, "EXTERNAL")
        self.assertEqual(rows[0].status, "behind")
        self.assertIn("7 commit(s)", rows[0].detail)

    def test_a_changed_content_pin_is_CHANGED_not_stale(self):
        # deps.yaml greps for '^CHANGED:' to escalate the issue title, because a
        # rewritten unversioned installer is a trust decision, not an update.
        self._stub_github()
        bump_deps.sha256_of_url = lambda url: "f" * 64
        with fixture_repo():
            rows = bump_deps.gather({"rustup"})
        self.assertEqual(rows[0].klass, "CONTENT")
        self.assertEqual(rows[0].status, "CHANGED")

    def test_a_rotated_anchor_is_ROTATED_and_never_auto_bumped(self):
        self._stub_github()
        bump_deps.gpg_fingerprint = lambda url: "B" * 40
        with fixture_repo() as repo:
            rows = bump_deps.gather({"eza-key"})
            after = read(repo, ".chezmoiscripts/linux/run_onchange_before_10_installs.sh.tmpl")
        self.assertEqual(rows[0].klass, "ANCHOR")
        self.assertEqual(rows[0].status, "ROTATED")
        # gather() must never rewrite a security anchor as a side effect.
        self.assertIn('EZA_KEY_FPR="' + "A" * 40 + '"', after)

    def test_a_missing_gpg_is_unverifiable_not_a_crash(self):
        self._stub_github()
        bump_deps.gpg_fingerprint = lambda url: ""
        with fixture_repo():
            rows = bump_deps.gather({"eza-key"})
        self.assertEqual(rows[0].status, "unverifiable")
        self.assertIn("gpg missing", rows[0].detail)

    def test_the_deps_workflow_grep_matches_the_status_strings(self):
        # deps.yaml runs: grep -qE '^(ROTATED|CHANGED):' over --check output, and
        # --check prints "{status}: {name} ...". This asserts the two agree; they
        # live in different files with nothing else connecting them.
        import re

        pattern = re.compile(r"^(ROTATED|CHANGED):")
        for status in ("ROTATED", "CHANGED"):
            line = f"{status}: eza-key (ANCHOR) AAAA -> BBBB"
            self.assertTrue(pattern.match(line), line)
        # And the routine statuses must NOT trip it.
        for status in ("stale", "behind", "unverifiable"):
            self.assertIsNone(pattern.match(f"{status}: x (VERSION) a -> b"))


class Registry(unittest.TestCase):
    """The pin registry itself."""

    def test_every_pattern_has_exactly_one_capture_group(self):
        # replace_value() rebuilds the match around m.group(1); a pattern with a
        # different number of groups would silently edit the wrong text.
        import re

        for group in (bump_deps.VERSION_PINS, bump_deps.CONTENT_PINS, bump_deps.ANCHOR_PINS):
            for entry in group:
                compiled = re.compile(entry["pattern"])
                self.assertEqual(
                    compiled.groups, 1, f"{entry['name']}: {entry['pattern']}"
                )

    def test_pin_names_are_unique(self):
        names = [
            e["name"]
            for g in (bump_deps.VERSION_PINS, bump_deps.CONTENT_PINS, bump_deps.ANCHOR_PINS)
            for e in g
        ]
        self.assertEqual(len(names), len(set(names)), names)

    def test_every_registered_pin_resolves_against_the_real_repo(self):
        # No fixture here on purpose: this is the test that notices when someone
        # renames a variable in install.sh or ci.yaml and forgets the registry.
        for group in (bump_deps.VERSION_PINS, bump_deps.CONTENT_PINS, bump_deps.ANCHOR_PINS):
            for entry in group:
                with self.subTest(pin=entry["name"]):
                    self.assertTrue(bump_deps.current_value(entry))

    def test_the_real_repo_satisfies_its_own_invariants(self):
        self.assertEqual(bump_deps.check_invariants(), [])


# Convenience aliases so tests can build variants of a fixture.
from helper import CI_YAML as FIXTURE_CI  # noqa: E402
from helper import EXTERNALS_YAML as FIXTURE_EXTERNALS  # noqa: E402
from helper import INSTALL_SH as FIXTURE_INSTALL  # noqa: E402


def read_fixture_ci() -> str:
    return FIXTURE_CI


# The archive refs the fixture externals already pin, so "upstream HEAD" defaults
# to "no change" and a test that wants drift has to ask for it explicitly.
FIXTURE_HEADS = {
    "sindresorhus/pure": "1" * 40,
    "agkozak/zsh-z": "2" * 40,
}


def current_tag(repo: str) -> str:
    """The tag the fixture already pins, so 'nothing changed' is the default."""
    return {
        "twpayne/chezmoi": "v2.71.1",
        "koalaman/shellcheck": "v0.11.0",
        "actions/checkout": "v7.0.1",
        "gitleaks/gitleaks-action": "v3.0.0",
        "jesseduffield/lazygit": "v0.58.0",
        "bats-core/bats-core": "v1.14.0",
    }[repo]


if __name__ == "__main__":
    unittest.main()
