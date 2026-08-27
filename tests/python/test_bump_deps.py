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

import os
import unittest

from helper import (
    ALL_REGISTRIES,
    CHECKOUT_SHA,
    GITLEAKS_SHA,
    LINUX_TMPL,
    REPO_ROOT,
    SINGLE_GROUP_REGISTRIES,
    bump_deps,
    fixture_repo,
    pin,
    read,
)

Problem = bump_deps.Problem

# What the fixture workflows pin, so "upstream has not moved" is the default and a
# test wanting drift has to say so.
FIXTURE_ACTION_SHAS = {
    "actions/checkout": CHECKOUT_SHA,
    "gitleaks/gitleaks-action": GITLEAKS_SHA,
}


class CurrentValue(unittest.TestCase):
    """Reading a pin out of a file."""

    def test_reads_a_single_occurrence(self):
        with fixture_repo():
            self.assertEqual(bump_deps.current_value(pin("chezmoi")), "v2.71.1")
            self.assertEqual(bump_deps.current_value(pin("shellcheck")), "v0.11.0")
            self.assertEqual(bump_deps.current_value(pin("lazygit")), "0.58.0")

    def test_occurrences_all_accepts_repeats(self):
        # shellcheck is installed twice in the fixture CI file -- once in `lint`,
        # once in `workflows`, mirroring the real tree.
        with fixture_repo():
            self.assertEqual(bump_deps.current_value(pin("shellcheck")), "v0.11.0")

    def test_missing_pattern_is_a_problem(self):
        with fixture_repo(**{"install.sh": "#!/bin/sh\necho nothing pinned here\n"}):
            with self.assertRaises(Problem) as ctx:
                bump_deps.current_value(pin("chezmoi"))
            self.assertIn("pattern not found", str(ctx.exception))

    def test_inconsistent_values_are_a_problem(self):
        # Two different shellcheck versions in one workflow: bumping either one
        # would leave the other behind, so this must abort rather than pick one.
        broken = read_fixture_ci().replace(
            "ACTIONLINT_VERSION: v1.7.12", "SHELLCHECK_VERSION: v0.9.0"
        )
        with fixture_repo(**{".github/workflows/ci.yaml": broken}):
            with self.assertRaises(Problem) as ctx:
                bump_deps.current_value(pin("shellcheck"))
            self.assertIn("inconsistent values", str(ctx.exception))

    def test_occurrence_count_mismatch_is_a_problem(self):
        # This guard is what stops a silent edit of the wrong number of lines.
        doubled = read_fixture_ci().replace(
            "          ZIZMOR_VERSION: v1.28.0",
            "          ZIZMOR_VERSION: v1.28.0\n          ZIZMOR_VERSION: v1.28.0",
        )
        with fixture_repo(**{".github/workflows/ci.yaml": doubled}):
            with self.assertRaises(Problem) as ctx:
                bump_deps.current_value(pin("zizmor"))
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
            n = bump_deps.replace_value(pin("shellcheck"), "v0.11.0", "v0.12.0")
            self.assertEqual(n, 2)
            self.assertNotIn("v0.11.0", read(repo, ".github/workflows/ci.yaml"))

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

    # The next four invert what this file used to assert. Until hash pinning landed
    # the check demanded an exact vX.Y.Z tag and reported a commit SHA as a
    # "floating tag" -- which had it backwards, since a tag can be force-moved and a
    # tag pin leaves zizmor's provenance audits nothing to inspect.

    def test_an_action_on_a_floating_major_tag_is_caught(self):
        floating = FIXTURE_CI.replace(f"actions/checkout@{CHECKOUT_SHA} # v7.0.1", "actions/checkout@v7")
        with fixture_repo(**{".github/workflows/ci.yaml": floating}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("commit SHA" in p for p in problems), problems)

    def test_an_action_on_an_exact_tag_is_still_caught(self):
        # An exact release tag is no longer good enough: v7.0.1 can be moved to
        # point somewhere else, and the pin would follow it.
        tagged = FIXTURE_CI.replace(f"actions/checkout@{CHECKOUT_SHA} # v7.0.1", "actions/checkout@v7.0.1")
        with fixture_repo(**{".github/workflows/ci.yaml": tagged}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("commit SHA" in p for p in problems), problems)

    def test_a_gitleaks_action_on_a_floating_tag_is_caught(self):
        floating = FIXTURE_CI.replace(f"gitleaks-action@{GITLEAKS_SHA} # v3.0.0", "gitleaks-action@v3")
        with fixture_repo(**{".github/workflows/ci.yaml": floating}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("commit SHA" in p for p in problems), problems)

    def test_a_commit_sha_without_a_version_comment_is_caught(self):
        # The comment is load-bearing: it is what a human reads instead of the
        # hash, and zizmor's ref-version-mismatch audit verifies it. A bare SHA is
        # immutable but unreadable, so it does not satisfy the invariant either.
        bare = FIXTURE_CI.replace(
            f"actions/checkout@{CHECKOUT_SHA} # v7.0.1", f"actions/checkout@{CHECKOUT_SHA}"
        )
        with fixture_repo(**{".github/workflows/ci.yaml": bare}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("vX.Y.Z" in p for p in problems), problems)

    def test_one_bad_pin_among_several_good_ones_is_caught(self):
        # Regression: the check used to re.search the file as a whole, so it passed
        # as long as *one* well-formed pin existed anywhere in it. ci.yaml pins
        # checkout six times; reverting a single one to a tag slipped through.
        one_reverted = FIXTURE_CI.replace(
            f"actions/checkout@{CHECKOUT_SHA} # v7.0.1", "actions/checkout@v7.0.1", 1
        )
        # The other pin is still correct -- that is the whole point of the case.
        self.assertIn(f"actions/checkout@{CHECKOUT_SHA} # v7.0.1", one_reverted)
        with fixture_repo(**{".github/workflows/ci.yaml": one_reverted}):
            problems = bump_deps.check_invariants()
        self.assertTrue(any("commit SHA" in p for p in problems), problems)

    def test_the_second_workflow_is_checked_too(self):
        # deps.yaml pins actions/checkout as well, and was invisible to bump-deps
        # before ACTION pins carried a list of files -- so `--apply` would rewrite
        # ci.yaml, leave this file behind, and then report everything current.
        stale = DEPS_YAML.replace(f"actions/checkout@{CHECKOUT_SHA} # v7.0.1", "actions/checkout@v7")
        with fixture_repo(**{".github/workflows/deps.yaml": stale}):
            problems = bump_deps.check_invariants()
        self.assertTrue(
            any("deps.yaml" in p and "commit SHA" in p for p in problems), problems
        )

    def test_an_unregistered_key_fingerprint_is_caught(self):
        # Exactly the failure above, one class over: the fingerprint in the install
        # script blocks a bad key at install time, but only an ANCHOR_PINS entry
        # makes deps.yaml fetch the live key weekly. Add the first without the
        # second and the pin is never checked, while the report still lists every
        # anchor it knows about as "current".
        added = LINUX_TMPL.replace(
            'EZA_KEY_FPR="' + "A" * 40 + '"',
            'EZA_KEY_FPR="' + "A" * 40 + '"\nSOMEVENDOR_KEY_FPR="' + "D" * 40 + '"',
        )
        with fixture_repo(
            **{".chezmoiscripts/linux/run_onchange_before_10_installs.sh.tmpl": added}
        ):
            problems = bump_deps.check_invariants()
        self.assertTrue(
            any("SOMEVENDOR_KEY_FPR" in p and "ANCHOR_PINS" in p for p in problems),
            problems,
        )

    def test_a_registered_key_fingerprint_is_not_flagged(self):
        # Guards against the check degenerating into "any fingerprint is a
        # problem", which would fire on the clean tree and get deleted.
        with fixture_repo():
            problems = bump_deps.check_invariants()
        self.assertEqual([p for p in problems if "ANCHOR_PINS" in p], [])


class ReplaceActionPin(unittest.TestCase):
    """Rewriting an ACTION pin: both halves, every file, nothing else."""

    def test_rewrites_commit_and_comment_together(self):
        with fixture_repo() as repo:
            n = bump_deps.replace_action_pin(pin("actions/checkout"), "e" * 40, "v8.0.0")
            self.assertEqual(n, 3)  # two in ci.yaml, one in deps.yaml
            for rel in (".github/workflows/ci.yaml", ".github/workflows/deps.yaml"):
                text = read(repo, rel)
                self.assertIn(f"actions/checkout@{'e' * 40} # v8.0.0", text)
                # A commit whose comment still claims the old release is the
                # specific state this class exists to make impossible.
                self.assertNotIn(CHECKOUT_SHA, text)
                self.assertNotIn("v7.0.1", text)

    def test_spans_every_file_in_the_pin(self):
        # The regression guard for deps.yaml having been invisible: rewriting only
        # the first file must not be mistaken for success.
        with fixture_repo() as repo:
            bump_deps.replace_action_pin(pin("actions/checkout"), "e" * 40, "v8.0.0")
            self.assertIn("e" * 40, read(repo, ".github/workflows/deps.yaml"))

    def test_leaves_other_actions_alone(self):
        with fixture_repo() as repo:
            bump_deps.replace_action_pin(pin("actions/checkout"), "e" * 40, "v8.0.0")
            text = read(repo, ".github/workflows/ci.yaml")
        self.assertIn(f"gitleaks/gitleaks-action@{GITLEAKS_SHA} # v3.0.0", text)

    def test_line_count_never_changes(self):
        with fixture_repo() as repo:
            before = read(repo, ".github/workflows/ci.yaml").count("\n")
            bump_deps.replace_action_pin(pin("actions/checkout"), "e" * 40, "v8.0.0")
            after = read(repo, ".github/workflows/ci.yaml").count("\n")
        self.assertEqual(before, after)

    def test_nothing_to_replace_is_a_problem(self):
        empty = {".github/workflows/ci.yaml": "name: CI\n", ".github/workflows/deps.yaml": "name: d\n"}
        with fixture_repo(**empty):
            with self.assertRaises(Problem):
                bump_deps.replace_action_pin(pin("actions/checkout"), "e" * 40, "v8.0.0")

    def test_reads_back_what_it_wrote(self):
        # replace_action_pin must leave text the pattern still matches; otherwise
        # the next --check reports "pattern not found" instead of a clean tree.
        with fixture_repo():
            bump_deps.replace_action_pin(pin("actions/checkout"), "e" * 40, "v8.0.0")
            self.assertEqual(
                bump_deps.current_action_pin(pin("actions/checkout")), ("e" * 40, "v8.0.0")
            )


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

    def _stub_github(self, latest=None, head=None, tag=None, ahead=0, commits=None):
        """Default to "upstream is exactly what the fixture pins", so a test only
        has to describe the one thing it wants to be different."""
        latest = latest or {}
        commits = commits or {}
        bump_deps.latest_release = lambda repo: latest.get(repo, current_tag(repo))
        bump_deps.head_sha = lambda repo: head or FIXTURE_HEADS[repo]
        bump_deps.nearest_tag = lambda repo: tag if tag is not None else "0.14.0"
        bump_deps.ahead_by = lambda repo, sha: ahead
        # ACTION pins resolve a tag to its commit. Default to the SHA the fixture
        # already pins, so "upstream has not moved" needs no per-test setup.
        bump_deps.tag_commit = lambda repo, t: commits.get(repo, FIXTURE_ACTION_SHAS[repo])

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

    def test_an_action_whose_release_moved_is_flagged(self):
        # Upstream cut v8.0.0, so both the commit and the comment are behind.
        self._stub_github(
            latest={"actions/checkout": "v8.0.0"},
            commits={"actions/checkout": "c" * 40},
        )
        with fixture_repo():
            rows = bump_deps.gather({"actions/checkout"})
        self.assertEqual(rows[0].klass, "ACTION")
        self.assertEqual(rows[0].status, "stale")
        self.assertEqual(rows[0].latest, ("c" * 40)[:12])
        self.assertIn("v7.0.1 -> v8.0.0", rows[0].detail)

    def test_an_action_whose_comment_alone_is_wrong_is_flagged(self):
        # The commit is current but the comment claims a different release. zizmor's
        # ref-version-mismatch catches this in CI; bump-deps must not call it
        # "current" and paper over it, because the comment is what humans read.
        # Mislabeled in *both* files, so this is a wrong comment rather than the
        # cross-file drift the next test covers.
        old, new = f"actions/checkout@{CHECKOUT_SHA} # v7.0.1", f"actions/checkout@{CHECKOUT_SHA} # v5.0.0"
        self._stub_github()
        with fixture_repo(
            **{
                ".github/workflows/ci.yaml": FIXTURE_CI.replace(old, new),
                ".github/workflows/deps.yaml": DEPS_YAML.replace(old, new),
            }
        ):
            rows = bump_deps.gather({"actions/checkout"})
        self.assertEqual(rows[0].status, "stale")
        # The commit did not move, so only the comment needs correcting.
        self.assertEqual(rows[0].current, rows[0].latest)
        self.assertIn("v5.0.0 -> v7.0.1", rows[0].detail)

    def test_an_action_pinned_differently_in_each_workflow_aborts(self):
        # The failure mode ACTION pins exist to prevent: one file bumped, the other
        # forgotten. Picking a winner and rewriting the rest would hide it.
        drifted = DEPS_YAML.replace(CHECKOUT_SHA, "d" * 40)
        self._stub_github()
        with fixture_repo(**{".github/workflows/deps.yaml": drifted}):
            with self.assertRaises(Problem) as ctx:
                bump_deps.gather({"actions/checkout"})
        self.assertIn("inconsistent pins", str(ctx.exception))

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

    def test_the_deps_workflow_routes_every_status_it_can_see(self):
        # deps.yaml greps --check's output to choose between opening a pull
        # request and opening the tracking issue, and --check prints
        # "{status}: {name} ...". The two live in different files with nothing
        # else connecting them, so a status matched by neither grep would be
        # reported by --check -- rc 1, job green -- and then acted on by nobody,
        # while the close-the-issue step tidied away last week's notice on its
        # way past. Read the real workflow rather than restating its patterns.
        import inspect
        import re

        workflow = os.path.join(REPO_ROOT, ".github", "workflows", "deps.yaml")
        with open(workflow, encoding="utf-8") as fh:
            yaml_text = fh.read()
        greps = {
            name: pattern
            for pattern, name in re.findall(
                r"grep -qE '([^']+)' /tmp/report\.txt; then\n\s*echo \"(\w+)=true\"",
                yaml_text,
            )
        }
        self.assertEqual(set(greps), {"bumpable", "manual", "security"}, greps)

        # Every status gather() can put on an actionable row. All but one are
        # written as `"current" if ... else "X"`; `unverifiable` is the exception,
        # because a missing gpg leaves nothing to compare against.
        src = inspect.getsource(bump_deps.gather)
        statuses = set(re.findall(r'else "([A-Za-z]+)"', src)) | {"unverifiable"}
        self.assertLessEqual({"stale", "behind", "CHANGED", "ROTATED"}, statuses)

        # Exactly one bucket each: a status in both would open a PR *and* an
        # issue for the same pin, and one in neither is the silent case above.
        buckets = {name: re.compile(greps[name]) for name in ("bumpable", "manual")}
        for status in sorted(statuses):
            with self.subTest(status=status):
                line = f"{status}: some-pin (VERSION) aaaa -> bbbb"
                hit = [name for name, pat in buckets.items() if pat.search(line)]
                self.assertEqual(len(hit), 1, f"{status!r} routed to {hit}")

        # An invariant violation is neither a version nor a fingerprint, and
        # --apply cannot fix one: it must reach the issue and never the PR.
        violation = "invariant: .chezmoiversion (2.99.0) exceeds install.sh"
        self.assertTrue(buckets["manual"].search(violation))
        self.assertIsNone(buckets["bumpable"].search(violation))

        # Only the two trust decisions escalate the issue title.
        security = re.compile(greps["security"])
        for status in ("ROTATED", "CHANGED"):
            self.assertTrue(security.match(f"{status}: eza-key (ANCHOR) AAAA -> BBBB"))
        for status in ("stale", "behind", "unverifiable"):
            self.assertIsNone(security.match(f"{status}: x (VERSION) a -> b"))


class Registry(unittest.TestCase):
    """The pin registry itself."""

    def test_every_pattern_has_exactly_one_capture_group(self):
        # replace_value() rebuilds the match around m.group(1); a pattern with a
        # different number of groups would silently edit the wrong text. ACTION
        # pins are excluded because they carry two groups by design and are
        # rewritten by replace_action_pin() instead -- see the next test.
        import re

        for group in SINGLE_GROUP_REGISTRIES:
            for entry in group:
                compiled = re.compile(entry["pattern"])
                self.assertEqual(
                    compiled.groups, 1, f"{entry['name']}: {entry['pattern']}"
                )

    def test_every_action_pattern_has_exactly_two_capture_groups(self):
        # replace_action_pin() reads group(1) as the commit and group(2) as the
        # version comment. A pattern with any other shape would rewrite the wrong
        # half, or silently leave the comment pointing at the old release.
        import re

        for entry in bump_deps.ACTION_PINS:
            compiled = re.compile(entry["pattern"])
            self.assertEqual(compiled.groups, 2, f"{entry['name']}: {entry['pattern']}")

    def test_pin_names_are_unique(self):
        names = [e["name"] for g in ALL_REGISTRIES for e in g]
        self.assertEqual(len(names), len(set(names)), names)

    def test_every_registered_pin_resolves_against_the_real_repo(self):
        # No fixture here on purpose: this is the test that notices when someone
        # renames a variable in install.sh or ci.yaml and forgets the registry.
        for group in SINGLE_GROUP_REGISTRIES:
            for entry in group:
                with self.subTest(pin=entry["name"]):
                    self.assertTrue(bump_deps.current_value(entry))
        for entry in bump_deps.ACTION_PINS:
            with self.subTest(pin=entry["name"]):
                sha, version = bump_deps.current_action_pin(entry)
                self.assertRegex(sha, r"^[0-9a-f]{40}$")
                self.assertRegex(version, r"^v?\d+\.\d+\.\d+$")

    def test_the_real_repo_satisfies_its_own_invariants(self):
        self.assertEqual(bump_deps.check_invariants(), [])


# Convenience aliases so tests can build variants of a fixture.
from helper import CI_YAML as FIXTURE_CI  # noqa: E402
from helper import DEPS_YAML  # noqa: E402
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
        "zizmorcore/zizmor": "v1.28.0",
        "rhysd/actionlint": "v1.7.12",
        "astral-sh/ruff": "0.16.0",
    }[repo]


if __name__ == "__main__":
    unittest.main()
