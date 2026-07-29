# Tests

```bash
tests/run              # everything
tests/run bats         # shell only
tests/run python       # bin/bump-deps only
bats tests/bats/secret.bats            # one suite
cd tests/python && python3 -m unittest # one runner, verbose
```

`tests/` is listed in `.chezmoiignore`, so none of this is copied into `$HOME`.

## Dependencies

| Suite | Needs |
|-------|-------|
| bats suites | `bats-core` (`brew install bats-core`, or the pinned tarball CI installs) |
| `herdr_reload_all.bats` | `jq` |
| `templates.bats` | `chezmoi` |
| `test_bump_deps.py` | python3 only — no pip, no `gh`, no network |

Missing `jq`, `zsh` or `chezmoi` makes the affected tests **skip**, not fail, so
they stay runnable on a half-configured machine. CI asserts separately that
nothing skipped, because a silently hollowed-out suite still reports success.

## What is tested, and why these things

Not everything here is worth a test. The `git-*` helpers are 1–13 line wrappers
around one git command; testing them would only restate them. What is covered is
the code where a bug is either invisible or dangerous:

- **`bin/secret`** — `shell_quote`'s output is `eval`'d by *every* interactive
  shell via `eval "$(secret env)"` in `~/.localrc`. A quoting bug there is code
  execution at shell startup, not a formatting nit. `helpers/values.bash` holds
  the adversarial values; each one breaks a different naive implementation, and
  each is round-tripped through both bash and zsh.
- **`bin/herdr-reload-all`** — reloading an *agent* pane types `reload` into a
  running agent's prompt. The `select(.agent == null)` filter that prevents it is
  asserted by pane id.
- **`templates.bats`** — the traps CLAUDE.md documents, several of which have
  already bitten: a bare `#` in `.chezmoi.yaml.tmpl` swallowing the next key, and
  `dot_gitconfig.tmpl` needing `get . "work"` rather than `.work` (a machine
  initialized before the key existed has no `work` entry, and `.work` against
  such a map is a hard error, not a falsy value).
- **`invariants.bats`** — contracts between two files that no linter can see:
  `.chezmoiignore` covering every topic directory, the zsh cache path matching in
  `dot_zshrc` and `zsh/completion.zsh`, tmux↔herdr keybinding parity.
- **`test_bump_deps.py`** — `bump-deps --self-test` already proves in-place
  editing is surgical, but it runs against the real files and cannot reach
  `check_invariants()` at all. These tests use a fixture repo, which makes every
  violation branch reachable.

  The `ACTION` pin class gets disproportionate coverage for its size, because two
  of its failure modes are silent. A pin rewritten in `ci.yaml` but not
  `deps.yaml` leaves the tree inconsistent while `--check` still reports
  "current"; and a commit updated without its `# vX.Y.Z` comment leaves the
  comment lying about what actually runs. Both are invisible in a diff review,
  so `fixture_repo` carries **both** workflow files and the tests assert across
  them.

## The zizmor canary is CI-only, deliberately

`tests/fixtures/zizmor/canary.yml` is not run by `tests/run`. It is consumed by
the `workflows` job in CI, which is the only place a `GH_TOKEN` exists — and
proving zizmor's *online* audits ran is the fixture's entire purpose. Wiring it
into the local suite would mean it skips on any machine without zizmor, and CI's
"nothing skipped" assertion would then fail for a dependency the `test` job has
no reason to install. See CLAUDE.md for what the canary asserts and why.

## How the shell tests avoid the real world

`helpers/stub.bash` puts a per-test directory at the front of `PATH` and writes
executable stubs into it.

- **`security` is always stubbed** (`helpers/keychain.bash`). It is macOS-only, so
  without a stub none of `bin/secret` could be tested on Ubuntu — and a test suite
  must not be able to touch a real login keychain even by accident. `$SECRET_ACCOUNT`
  and `$SECRET_ENV_NAME` are also set to throwaway values as a second line of
  defense.
- **`herdr` is stubbed**; the real one drives live panes. Its `pane run` stub logs
  the pane ids it was given, which is how "no agent pane was reloaded" is asserted.
- **`jq` is deliberately *not* stubbed.** `herdr-reload-all`'s behavior largely
  *is* its jq filters; stubbing jq would test nothing.

To exercise a "dependency not installed" branch, use `only_stubs`:

```bash
run env PATH="$(only_stubs)" "$SCRIPT"
```

That restricts `PATH` for the one invocation. Don't assign to the test shell's
own `PATH` — bats' post-test cleanup shells out to `rm`, and a truncated `PATH`
breaks the harness instead of the code under test.

## Adding a test

New topic directory or `bin/` script? `invariants.bats` derives its file lists
from globs, so most of it covers new files automatically.

For a new suite, `load helpers/stub.bash` gets you `setup_sandbox`, `make_stub`,
`only_stubs`, and the `assert_*` helpers. Scripts that run `main "$@"` need the
sourced-guard that `bin/secret` and `bin/herdr-reload-all` have before individual
functions can be called directly:

```bash
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
```

Use `if/then`, not `[ ... ] && main "$@"` — the latter leaves a non-zero status
as the last command when sourced, and `set -e` then kills the sourcing shell.

## Proving a test bites

A test that cannot fail is worse than no test. Break the thing, watch it go red,
put it back:

| Break | Should fail |
|-------|-------------|
| `bin/secret`: change `shell_quote`'s sed to `s/'/\\'/g` | 3 secret tests |
| `bin/herdr-reload-all`: `select(.agent == null)` → `select(.)` | agent-pane test |
| `.chezmoiversion` → `2.99.0` | `test_floor_above_...`, and an invariants test |
| remove `bin/` from `.chezmoiignore` | `invariants.bats` |
| edit `HOMEBREW_CASK_OPTS` in `homebrew/exports.zsh` only | `templates.bats` |
| revert any `actions/checkout` pin in `ci.yaml` to `@v7.0.1` | `test_the_real_repo_satisfies_its_own_invariants` |
| change the `# v7.0.1` comment beside a checkout SHA to `# v6.0.0` | `bump-deps --check`, and zizmor's `ref-version-mismatch` in CI |
| drop `deps.yaml` from `ACTION_PINS`'s `files` | `test_the_second_workflow_is_checked_too` |
| `replace_action_pin`: stop rewriting `m.group(2)` | `bump-deps --self-test`, and 2 `ReplaceActionPin` tests |
| correct `tests/fixtures/zizmor/canary.yml`'s version comment | the `workflows` job's canary step (CI only) |
