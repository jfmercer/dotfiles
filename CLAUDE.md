# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [chezmoi](https://github.com/twpayne/chezmoi)-managed dotfiles repository. The source directory lives at `~/.local/share/chezmoi`; chezmoi applies it to `$HOME`.

## Key commands

```bash
chezmoi apply          # apply changes from source to home directory
chezmoi diff           # preview what apply would change (uses delta)
chezmoi status         # show what's out of sync between source and $HOME
chezmoi add <file>     # track a new file from $HOME into this repo
chezmoi re-add <file>  # pull changes made directly in $HOME back into source
chezmoi edit <file>    # edit a tracked file in the source directory
chezmoi cd             # cd into the source directory
```

Apply to a fresh machine (one-liner):
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jfmercer/dotfiles/master/scripts/install_dotfiles.sh)"
```

## Working with changes

Edits to tracked files only take effect in `$HOME` after `chezmoi apply` runs — the source directory and `$HOME` can diverge. Before testing a change (e.g. running a tool to see if a config edit worked) or claiming a change is in effect, check whether `chezmoi apply` has been run since the edit (e.g. `chezmoi status` or diff the source file against its `$HOME` target). If it hasn't, remind the user it needs to be run — either to make the change live, or before you can test it yourself.

## Architecture

### File naming conventions (chezmoi)
- `dot_foo` → `.foo` in `$HOME`
- `dot_config/bar` → `~/.config/bar`
- `*.tmpl` → processed as Go templates before applying
- `empty_*` → creates an empty file
- `.chezmoiscripts/` → scripts run by chezmoi at specific lifecycle points

### Template data (`.chezmoi.yaml.tmpl`)
Prompts for `email`, `install_mac_apps`, `install_linux_apps`, `set_git_to_ssh`, and `work` at init time. These are available in templates as `.email`, `.install_mac_apps`, etc. In CI they default to `true`, except `work`, which defaults to `false`. Reference `work` defensively as `get . "work"` so it stays safe on machines whose generated config (`~/.config/chezmoi/chezmoi.yaml`) predates the key — chezmoi reads that generated file, not the `.tmpl`, until `chezmoi init` is re-run.

**Comment with `{{/* … */}}`, never with a bare `#`.** A `#` comment in this file is emitted verbatim into the rendered YAML, and the surrounding whitespace-stripping delimiters swallow its trailing newline — which silently commented out `verbose: true` for a long time. Verify any edit with `chezmoi execute-template --init < .chezmoi.yaml.tmpl`.

Because this file is rendered into `~/.config/chezmoi/chezmoi.yaml` at `chezmoi init` time, editing the template alone changes nothing on an existing machine. Re-run `chezmoi init` (or edit the generated file) to pick up new keys or changed defaults.

**Work machines.** `work: true` makes `dot_gitconfig.tmpl` include an untracked `~/.gitconfig.work`. Employer-specific values (internal hostnames, URL rewrites) belong in that file, never in this repo — it is public. `~/.gitconfig.work` must be recreated by hand on each work machine; git silently ignores the include when it is absent, so a missing file degrades to "no rewrite" rather than an error.

### Script lifecycle
Scripts in `.chezmoiscripts/` root run on all platforms; those in `darwin/` or `linux/` subdirs run only on that platform.
- `.chezmoiscripts/darwin/run_onchange_before_10_homebrew.sh.tmpl` — installs Homebrew packages/casks (macOS only). Puts `brew` on `PATH` itself via a prefix-detection loop: `chezmoi apply` is not an interactive zsh, so it does not inherit what `homebrew/path.zsh` sets, and on Apple Silicon `/opt/homebrew/bin` is not on the default `PATH`. It also exports `HOMEBREW_CASK_OPTS` (mirroring `homebrew/exports.zsh`) so apply-time cask installs get `--appdir=~/Applications` and `--require-sha`. Casks that upstream ships as `sha256 :no_check` cannot satisfy `--require-sha`, so they live in a separate `$casks_no_sha` list installed in a second pass with that flag dropped — keep that list as short as possible.
- `.chezmoiscripts/linux/` — parallel installs for Linux (apt-based, arm64)
- `.chezmoiscripts/darwin/run_after_20_zed_symlink.sh.tmpl` — symlinks Zed's CLI into `~/.local/bin/zed` (every apply, macOS only)
- `.chezmoiscripts/darwin/run_after_25_tailscale_cli.sh.tmpl` — puts Tailscale.app's CLI on `PATH` as `~/.local/bin/tailscale` via a small `exec` wrapper (not a symlink — the standalone Tailscale binary resolves its `.app` bundle from its launch path and panics through a symlink) (every apply, macOS only; no-op when Tailscale isn't installed)
- `.chezmoiscripts/run_after_30_asdf_completions.sh` — generates asdf zsh completions into `~/.asdf/completions` (every apply)
- `.chezmoiscripts/run_after_40_op_completions.sh` — generates 1Password CLI (`op`) zsh completions into `~/.cache/zsh/completions/_op`, only when `op` is installed (every apply; no-op otherwise, and `op` is not installed by this repo)
- `.chezmoiscripts/run_onchange_after_100_vim.sh.tmpl` — vim plugin setup
- `.chezmoiscripts/run_once_after_110_fix_git_upstream.sh.tmpl` — switches remote from HTTPS to SSH (runs once)

### External dependencies (`.chezmoiexternal.yaml`)
Chezmoi fetches these automatically (weekly refresh): vim-plug, zsh plugins (pure, autosuggestions, completions, history-substring-search, syntax-highlighting, zsh-z), and tmux plugins (tpm, resurrect, continuum, open, copycat, yank, themepack). They land in `~/.vim/`, `~/.local/zsh-plugins/`, and `~/.tmux/plugins/`.

**Every entry is pinned to an exact commit and checksummed with `checksum.sha256`.** These files are sourced into every interactive shell and tmux session, so tracking `master` unverified meant anyone able to push to any one of those repos got automatic code execution here within the refresh period. Do not "simplify" an entry back to `master.tar.gz`.

Pinned to **commits, not tags**: several of these projects stopped tagging years ago while `master` kept moving (tmux-yank's newest release is from 2018, five years behind its master), so "latest tag" silently *downgrades*. A commit SHA is content-addressed, which is at least as strong as a tag — tags can be force-moved, commits cannot.

If *several* entries fail a checksum at once with unchanged refs, suspect GitHub regenerating its auto-archives (it has happened once, in 2023) rather than a compromise — verify, then recompute.

### Bumping pinned dependencies — `bin/bump-deps`

Pins are spread across four files and Dependabot reads none of them. `bin/bump-deps` (Python 3, stdlib only, uses `gh` for the API) walks all of them:

```bash
bump-deps            # status table: class, current, latest
bump-deps --check    # terse; exit 1 if action needed (what CI runs)
bump-deps --apply    # bump versions; confirm each external individually
bump-deps --self-test  # prove the in-place editing is surgical
```

**A pin is not always a version.** The tool treats four classes differently, and conflating them would be harmful:

| Class | Where | Bumping means |
|-------|-------|---------------|
| `VERSION` | `install.sh`, `ci.yaml`, linux installs | Latest stable release. Automatic. |
| `ACTION` | `ci.yaml`, `deps.yaml` | A GitHub Action pinned to a commit SHA with a `# vX.Y.Z` comment. Resolves the latest release's tag to its commit and rewrites **both halves together**. Automatic. |
| `EXTERNAL` | `.chezmoiexternal.yaml` (14) | Move to master HEAD, recompute checksum. Confirmed per entry, because it pulls upstream code nobody has read. |
| `CONTENT` | `RUSTUP_INIT_SHA256` | A hash over an *unversioned* URL. A change means upstream rewrote the installer — a trust decision, so it needs `--accept rustup`. |
| `ANCHOR` | `EZA_KEY_FPR`, `CHARM_KEY_FPR` | A GPG public-key fingerprint. **Never rewritten automatically.** A mismatch is key rotation or an attack; verify against upstream's own announcement and edit by hand. `CHARM_KEY_FPR` (Charm's apt repo, for glow) carries an expiry of 2027-07-13, so it *will* rotate on schedule — unlike eza's. |

It also asserts cross-file invariants, notably that **`.chezmoiversion` must not exceed `install.sh`'s `CHEZMOI_VERSION`** — the floor is the minimum chezmoi allowed to read this source, so if it outruns the version the bootstrap installs, a fresh machine installs chezmoi and is then refused by it. It further rejects externals tracking a moving ref, and Actions **not** pinned to a commit SHA with a matching version comment.

It also requires that **every `*_KEY_FPR` in the linux installs script is registered in `ANCHOR_PINS`**. The fingerprint in the script only blocks a bad key at install time; it is the `ANCHOR_PINS` entry that makes `deps.yaml` fetch the live key weekly and report a rotation. Those live in two files, so before this check an unregistered pin was simply never watched — while the report went on listing every anchor it *did* know as `current`. Precisely the `deps.yaml` failure below, one pin class over: a staleness detector certifying something it had never read.

`.github/workflows/deps.yaml` runs `--check` weekly and keeps a single tracking issue in sync. It never commits — bumping stays deliberate.

#### Why Actions are hash-pinned, and why the comment is load-bearing

The invariant above used to demand the opposite — an exact `vX.Y.Z` tag, rejecting a commit SHA as a "floating tag". That was backwards, for the reason this file already gives for the externals: a tag can be force-moved by anyone able to push to the action's repo, a commit cannot. These run with a `GITHUB_TOKEN`, so it matters more here, not less.

The bigger point is that **hash-pinning is what makes the pin auditable at all.** Four zizmor audits inspect the SHA, and none of them can run on a tag pin:

| Audit | Verifies |
|---|---|
| `impostor-commit` | The commit came from that repo, not a **fork in its network**. GitHub serves any commit in a fork network from any repo URL in it, so `actions/checkout@<attacker-fork-sha>` resolves and looks legitimate. |
| `ref-version-mismatch` | The `# vX.Y.Z` comment actually corresponds to that commit. |
| `stale-action-refs` | The commit sits on a release tag, not an arbitrary mid-development one. |
| `known-vulnerable-actions` | No CVE against the pinned version. |

So the trailing comment is not decoration — it is checked, which is why `bump-deps` rewrites the SHA and the comment as one operation rather than leaving the comment to rot into a lie.

`actions/checkout` is pinned in **both** workflows, which is why an `ACTION` pin holds a list of files. Before this class existed only `ci.yaml` was registered, so `--apply` would rewrite five pins there, silently leave `deps.yaml` behind, and then report "all pins current" — the staleness detector certifying a file it had never read.

### Zsh loading order (`dot_zshrc`)
1. `*/exports.zsh` files — environment variables
2. `*/path.zsh` files — `$PATH` modifications
3. `zsh/prompt.zsh` — pure prompt
4. Plugins from `~/.local/zsh-plugins/` (order matters: syntax-highlighting before history-substring-search)
5. All remaining `*.zsh` files in topic directories (excluding `path.zsh`, `exports.zsh`, and `prompt.zsh`, already loaded above)
6. `~/.localrc` if present (machine-local secrets, not tracked)

**Pass 5 is alphabetical, and `brew shellenv` must not run in it.** `/opt/homebrew/bin` is in neither `/etc/paths` nor `/etc/paths.d`, so `homebrew/path.zsh` is the only thing that puts Homebrew on `PATH` — which is why it lives in pass 2 and must stay there. It used to be `homebrew/homebrew.zsh`, in pass 5, where every topic dir sorting before `homebrew/` (`asdf`, `atuin`, `fzf`, `git`, `gpg`) ran against a `PATH` that had no Homebrew on it yet. `cached-eval`'s `[[ -x $bin ]]` guard then took its silent `return 0`, so atuin's Ctrl-R and fzf's Ctrl-T/Alt-C were simply never bound — no error, no output, just a dead key.

It only broke shells whose *parent* had no Homebrew on `PATH`, which made it look intermittent: a shell started from another configured shell inherited enough `PATH` to work. herdr panes did not — Ghostty is a GUI launch, and the herdr server hands its own environment to every pane it spawns. So the symptom was "Ctrl-R does nothing in a new herdr tab" and nowhere else. An `invariants.bats` test now asserts `brew shellenv` is invoked from a `*/path.zsh`. Anything new that reaches for a Homebrew-installed binary is subject to the same rule: it either lives in pass 2 or later than `homebrew/` alphabetically.

Completion caches live under `$XDG_CACHE_HOME/zsh/` (`zcompdump`, `zcompcache/`), not in `$HOME`. `compinit` is invoked with an explicit `-d` for that reason; if you change the path, change it in both `dot_zshrc` and `zsh/completion.zsh`.

`TERM` is deliberately **not** set anywhere. Ghostty, tmux (`dot_tmux.conf` sets `tmux-256color`) and herdr each set it correctly; a blanket `export TERM=xterm-256color` used to overwrite all three. If an ssh target lacks a terminfo entry, fix it there (`infocmp -x | ssh host -- tic -x -`) or set `term =` in `dot_config/ghostty/config.tmpl`.

Startup performance: `dot_zshrc` defines a `cached-eval` helper that caches the output of `eval "$(cmd init ...)"` style hooks in `~/.cache/zsh/` and re-runs the command only when the tool's binary is newer than the cache (used by `atuin/atuin.zsh` and `homebrew/path.zsh`). Prefer `cached-eval <cache-name> <cmd> <args...>` over `eval "$(...)"` for new integrations, zsh builtin parameters (`$OSTYPE`, `$HOST`, `$TTY`, `$commands[...]`) over `$(uname)`/`$(tty)`/`$(which ...)` forks, and chezmoi apply-time scripts over per-shell setup work.

Completions: tool completions generated at apply time land in the shared `~/.cache/zsh/completions/` dir, which `dot_zshrc` adds to `fpath` before `compinit` (used by the `op` completions script). Drop a `_toolname` file there from a `run_after_*_completions.sh` script and `compinit` picks it up — no per-shell generation and no `fpath` change needed. (asdf is the exception: its completions live in asdf's own `~/.asdf/completions`, added to `fpath` by `asdf/asdf.zsh`.)

### Topical organization
Each tool/concern has its own directory with `.zsh` files:
- `exports.zsh` — env vars
- `path.zsh` — PATH additions
- `alii.zsh` — aliases
- `*.zsh` — everything else

Active topics: `asdf`, `atuin`, `fzf`, `git`, `gpg`, `homebrew`, `kali`, `macos`, `rust`, `system`, `zsh`.

Topic files are sourced on **every** platform — the `*/*.zsh` glob in `dot_zshrc` has no OS filter. Anything platform-specific needs its own guard inside the file (`[[ $OSTYPE == darwin* ]] || return 0` in `macos/alii.zsh`, `$HOST` matching in `kali/path.zsh`).

### `bin/` scripts
Custom executables that run in-place from the chezmoi source directory. `system/path.zsh` adds `$DOTFILES/bin` to `$PATH`, so nothing is copied or symlinked elsewhere. Before adding a new script, check here first:
- `bupdate` — `brew update && brew upgrade && brew cleanup`
- `bump-deps` — reports and bumps every pinned dependency across the four files that hold them; the only Python script in `bin/`. See "Bumping pinned dependencies" above.
- `git-*` — custom git subcommands: `backup-branch`, `checkout-default-branch`, `clean-submodules`, `copy-branch-name`, `delete-local-merged`, `nuke`, `promote`, `track`, `unpushed`, `unpushed-stat`, `up`
- `secret` — Keychain CRUD wrapper around macOS `security` (`set`/`get`/`rotate`/`rm` generic-password secrets; account defaults to `$USER`, override with `$SECRET_ACCOUNT`). Also provides the **env bundle** (`env` / `env-edit` / `env-import`) — see below.
- `ghostty-session` — what Ghostty runs as its `initial-command`; launches or attaches herdr, then falls through to a login shell. See "Ghostty starts herdr" below
- `herdr-reload-all` — re-execs the login shell (`reload`) in every herdr *shell* pane at once (agent panes skipped); for applying updated dotfiles across all tabs/workspaces. On a `herdr pane list` protocol mismatch (CLI newer than the running server, common after `brew upgrade herdr`) it prints how to restart the server rather than leaking raw JSON; it never restarts the server itself (that would kill every pane process, agents included)
- `enum`, `makeEnv` — misc utilities (Linux/Kali oriented)
- `start-bloodhound`, `tun0.sh`, `pycharm` — security/tool launchers
- `ps*.ps1` — PowerShell helpers (Base64 encode, reverse shell scaffold)
- `time-startup` — times 10 interactive zsh startups
- `update-discord` — downloads and installs the latest Discord .deb (Linux)

### Repository layout — this is a deliberate two-mode design, not a half-finished migration

The tree mixes chezmoi-native entries with Holman-style topical directories **on purpose**. Do not "finish the migration" by converting one into the other.

**The rule for new config:**
- Does it have to exist as a file in `$HOME` for some other program to read? → chezmoi-native: `dot_foo`, `dot_config/foo/`, `*.tmpl`.
- Is it only ever read by an interactive zsh, or executed by you from `$PATH`? → a topic directory or `bin/`, sourced/executed **in place** out of `$DOTFILES`.

Everything in the second group is listed in `.chezmoiignore` so chezmoi never copies it to `$HOME`. That is load-bearing, not cleanup debt: `dot_zshrc` sources `$DOTFILES/*/*.zsh` directly from the source directory, and `system/path.zsh` puts `$DOTFILES/bin` on `$PATH`. The upside is that editing a topic file or a `bin/` script takes effect in the next shell with no `chezmoi apply`; the tradeoff is that those files are invisible to `chezmoi diff`/`status`, so mistakes in them surface at shell startup rather than at apply time.

**Unmanaged (in `.chezmoiignore`):**
- Topic directories sourced in place: `asdf/`, `atuin/`, `fzf/`, `git/`, `gpg/`, `homebrew/`, `kali/`, `macos/`, `rust/`, `system/`, `zsh/`
- `bin/` — executables put on `$PATH` in place
- `terminal/` — **hand-applied** terminal profiles, see below
- `tests/` — the test suite; see "Tests" below
- `.claude/`, `.github/`, `.vscode/`, `scripts/`, `install.sh`, and the docs

### Hand-applied config — do not judge these by "is anything referencing it?"

Some files here are reference material that a human imports by hand. Nothing in the repo invokes them, so a grep for references finds nothing and they *look* dead. They are not. Before deleting anything on "unreferenced" grounds, check whether it belongs in this category — a repo-wide grep cannot distinguish "dead" from "applied manually".

- `terminal/MATE.terminal` — a **dconf dump** (starts `[global]`), for the MATE/GNOME terminal on Linux desktops:
  ```bash
  dconf load /org/mate/terminal/ < terminal/MATE.terminal
  ```
- `terminal/Monokai.terminal` — an Apple **plist**, a profile for macOS's native Terminal.app. Import via Terminal → Settings → Profiles → Import, or `open terminal/Monokai.terminal`.
- `terminal/Molokai.terminal` — the same kind of plist, but generated from **Ghostty's own `Molokai` theme**, so Terminal.app matches what `dot_config/ghostty/config.tmpl` sets. Despite the near-identical name it is *not* a variant of `Monokai.terminal`: every color differs (background `#121212` vs `#272822`, red `#fa2573` vs `#8a0031`), and it additionally defines `ANSIWhiteColor`/`ANSIBrightWhiteColor`, which `Monokai.terminal` omits. Both are kept — Monokai is the classic scheme, Molokai is the Ghostty-matching one.

All three are live. `MATE.terminal` was previously *also* loaded automatically by the Parrot bootstrap script; retiring Parrot removed that one automated caller but not the file's purpose.

Colors in these plists are `NSKeyedArchiver`-encoded `NSColor` objects (an `NSRGB` component string in device RGB, or `NSWhite` for grays) — **not** hex strings, so they cannot be hand-edited in a text editor. `Molokai.terminal`'s values were derived from Ghostty's own theme file (`Ghostty.app/Contents/Resources/ghostty/themes/Molokai`); re-derive them from that source rather than trying to patch a value in place. No script in this repo does that — it was a one-off, and deliberately not added to `bin/`, since these files change approximately never.

A profile's own colors are unaffected by the terminal's color depth — Terminal.app draws them from its settings at full 8-bit-per-channel fidelity, and always did. Color depth only ever governed what SGR sequences *applications* could express. As of Terminal.app 2.15 (macOS 26 Tahoe) that limit is gone too: it supports 24-bit color and sets `COLORTERM=truecolor`. Note it still reports `TERM=xterm-256color`, whose terminfo entry advertises no `Tc`/`RGB`, so apps sniffing terminfo instead of `COLORTERM` will still fall back to 256 colors. Do not "fix" that by setting `TERM` — see the `dot_zshrc` note above on why `TERM` is deliberately unset here.

`invariants.bats` asserts that whatever theme `dot_config/ghostty/config.tmpl` sets has a same-named profile in `terminal/`, with a matching `name` key (Terminal.app lists profiles by that key, not by filename). It is an **existence** check that never enumerates `terminal/`, so a theme change asks you to *add* a profile and can never implicate the ones already there. Do not "tighten" it into a check that every profile corresponds to a live theme — that would contradict this section's whole premise.

Note: `dot_config/zed/settings.json` (managed by chezmoi) is Zed's editor config, applied to `~/.config/zed/settings.json`; the Zed CLI symlink is handled by `.chezmoiscripts/darwin/run_after_20_zed_symlink.sh.tmpl`. `dot_config/ghostty/config.tmpl` (managed by chezmoi) is Ghostty's terminal config, applied to `~/.config/ghostty/config`. `dot_config/herdr/config.toml` (managed by chezmoi) is herdr's config, applied to `~/.config/herdr/config.toml`. `dot_config/glow/glow.yml` (managed by chezmoi) is glow's config, applied to `~/.config/glow/glow.yml`.

**Why glow's config lives under `dot_config/` even on macOS.** glow searches `$GLOW_CONFIG_HOME`, then `$XDG_CONFIG_HOME/glow`, then the platform config dir — which on macOS is `~/Library/Preferences/glow`, *not* `~/.config`. Because `dot_zshenv` exports `XDG_CONFIG_HOME`, the XDG path wins on both platforms and one tracked file covers both; without that export macOS would need a second, `Library/`-shaped copy. Its `pager: true` is what makes bare `glow foo.md` page — glow reads the key into the same variable `--pager` sets (`pager = viper.GetBool("pager")`), so it is equivalent to the flag, not a weaker default. Note glow does **not** gate paging on stdout being a TTY, so this applies to piped runs too; `less` passes through when stdout is not a terminal, so that is harmless.

### Secrets and shell startup: the `secret` env bundle

`~/.localrc` (untracked, machine-local) is where API tokens get exported. The
obvious way to write it is one Keychain lookup per variable:

```zsh
export SNYK_TOKEN=$(secret get snyk_api_key)     # ~48 ms, every shell
```

**Each of those costs a full Keychain round trip — measured at ~48 ms.** Ten of
them is ~480 ms added to *every* interactive shell, which was ~78% of total
startup. `zprof` does not reveal this: the cost is forks from a sourced file,
not time in shell functions.

Use the bundle instead. Every value still lives only in the Keychain, but in a
single item, so the shell pays one read:

```zsh
eval "$(secret env)"                              # in ~/.localrc
```

Measured over 10 variables: **~590 ms → ~90 ms.**

Managing it:

```bash
secret env-edit                                          # edit in $EDITOR
printf 'SNYK_TOKEN=snyk_api_key\n' | secret env-import   # build from existing items
secret env                                               # print it (what eval consumes)
```

The item is `$SECRET_ENV_NAME` (default `shell_env`), holding base64 of a block
of `export VAR='value'` lines — base64 because `security add-generic-password`
takes the value as an argument rather than on stdin. Values touch disk only as
a mode-0600 temp file during `env-edit`, removed on exit.

Two rules for `~/.localrc`, since it runs on every interactive shell:

- Never put a literal secret in it. Sensitive values belong in the Keychain and
  come back through the bundle.
- Watch per-line forks generally, not just Keychain reads. Three eager
  `ssh-add --apple-use-keychain` calls used to cost ~47 ms there. They are gone:
  `~/.ssh/config` has `AddKeysToAgent yes` + `UseKeychain yes` under `Host *`
  plus a per-host `IdentityFile`, so keys load on first use instead.

**SSH host-pattern gotcha, learned the hard way.** `Host *.github.com` does
**not** match `github.com` — the `*.` requires a subdomain. That config looked
correct for years while doing nothing; GitHub SSH only worked because the eager
`ssh-add` had pushed the key into the agent. Removing those lines without
fixing the pattern would have broken push access. `gitlab.com` had no
`IdentityFile` at all, hidden the same way — that key has since been retired and
its config block commented out, so don't go looking for it. Always verify with:

```bash
ssh -G github.com | grep -E '^identityfile'   # must list the intended key
SSH_AUTH_SOCK=/dev/null ssh -T git@github.com # proves it works without the agent
```

The `SSH_AUTH_SOCK=/dev/null` form is the important one: it bypasses the agent,
so it tests what a brand-new shell actually gets rather than what a
long-running agent happens to be holding.

### tmux / herdr alignment
`dot_tmux.conf` and `dot_config/herdr/config.toml` are intentionally kept aligned (same Ctrl-a prefix, `|`/`-` split keys, vi copy mode, session-persistence behavior). When changing a setting in one, mirror the equivalent setting in the other — the tmux↔herdr mapping lives as comments in `dot_config/herdr/config.toml`.

### Ghostty starts herdr

`dot_config/ghostty/config.tmpl` sets `initial-command` to `bin/ghostty-session`, so opening Ghostty lands you in herdr. **The launch-or-attach decision is herdr's, not ours** — bare `herdr` starts the headless server if it is not running and attaches to the existing session if it is. Nothing here inspects `herdr status`; don't add a check that duplicates it.

The wrapper exists for the three things herdr cannot do when the *GUI* starts it:

- **It finds the binary.** A GUI launch inherits none of the `PATH` that `homebrew/path.zsh` and `system/path.zsh` build — `PATH=/usr/bin:/bin sh -c 'command -v herdr'` fails, so `initial-command = herdr` would not resolve. `find_herdr` falls back to a prefix loop, the same problem and fix as in `run_onchange_before_10_homebrew.sh.tmpl`. `herdr_candidates` is a *function* so tests can redirect it; a constant would make the "herdr is not installed" test attach to a live session on a developer machine.
- **It cannot lock you out.** Ghostty closes the window when its command exits, so every exit path here ends in `exec "${SHELL:-/bin/zsh}" -l`: herdr missing, herdr failing to start, and herdr detaching (`ctrl-a q`) all leave a usable prompt with the output still on screen. herdr runs as a child, not `exec`, for exactly that reason.
- **It does not nest.** herdr exports `HERDR_ENV` in every pane and its `allow_nested` defaults to false. `HERDR_AUTOSTART=0` is the manual escape hatch.

Two consequences worth knowing:

- `initial-command`, not `command`, so new windows and `Cmd-T` tabs stay plain shells. Ghostty's docs are explicit that it applies only to the first surface ever created — **close that window and the next one is a plain shell until Ghostty restarts.** That is the accepted cost of the setting.
- **Do not set `shell-integration = zsh` to give the fallback shell Ghostty's cursor/title features.** Because `initial-command`'s basename is not a known shell, `detect` skips injection today. Forcing `zsh` injects `ZDOTDIR`, and since no shell runs before herdr to restore it, that `ZDOTDIR` leaks into the herdr **server** and therefore into every pane's shell — changing every pane to fix cosmetics on a rescue path.

Note that `tests/bats/ghostty_session.bats` unsets `HERDR_ENV`/`HERDR_AUTOSTART` in `setup`. The suite is usually run from inside a herdr pane, which exports the first one; without that, every test takes the nesting guard and passes for the wrong reason.

### `dot_gitignore` vs `.gitignore`
Two gitignore files coexist in this repo. `dot_gitignore` is managed by chezmoi and becomes `~/.gitignore` (the global gitignore). `.gitignore` is the repo's own gitignore and only excludes `system/linux.zsh`. When editing the global gitignore, use `dot_gitignore`.

### Go template notes
- `{{-` strips leading whitespace; `-}}` strips trailing whitespace
- OS detection pattern: `.chezmoi.os` (`"darwin"` / `"linux"`) and `.chezmoi.osRelease.id`
- Scripts guarded by `{{- if (eq .chezmoi.os "darwin") -}}` are no-ops on other platforms

## Tests

`tests/run` (bats + stdlib `unittest`). Full detail in `tests/README.md`; the
parts worth knowing before you touch anything:

- **`bats-core` is the shell runner**, `brew install bats-core` locally. CI
  installs a pinned, checksummed tarball and `bin/bump-deps` tracks the tag as a
  `VERSION` pin, so it cannot rot.
- **Coverage is deliberately uneven.** Most `git-*` helpers are 1–13 line wrappers
  and have no tests; testing them would only restate them. The exception is
  `bin/git-delete-local-merged`, which decides which branches to *destroy* and
  had been silently broken for years. Effort otherwise goes where a
  bug is invisible or dangerous: `bin/secret`'s `shell_quote` (its output is
  `eval`'d by every interactive shell), `bin/herdr-reload-all`'s agent-pane
  exclusion, `bin/ghostty-session`'s guarantee that every path ends at a login
  shell (it is Ghostty's `initial-command`, so a bug there is a terminal that
  will not open), the template traps documented above, and the cross-file
  invariants no linter can see.
- **`security` and `herdr` are stubbed; `jq` is not.** The first two are
  macOS-only or have real side effects. `herdr-reload-all`'s behavior largely
  *is* its jq filters, so stubbing jq would test nothing.
- **`bin/secret`, `bin/herdr-reload-all` and `bin/ghostty-session` end in a sourced-guard** so tests can
  reach individual functions. Use `if/then`, not `[ ... ] && main "$@"` — the
  latter leaves a non-zero status when sourced and `set -e` kills the caller.
  `herdr-reload-all`'s dependency checks live *inside* `main()` for the same
  reason.
- **`test_bump_deps.py` runs against a fixture repo**, not the real tree, which is
  what makes `check_invariants()`'s violation branches reachable at all.
  Registering a new pin in `bump-deps` means adding it to `tests/python/helper.py`
  too — that coupling is intentional.
- **A test that cannot fail is worse than none.** `tests/README.md` ends with a
  table of one-line breakages that must each turn the suite red; all nine were
  verified when the suite landed.

## CI

`.github/workflows/ci.yaml` has six jobs. The non-interactive template defaults (`install_mac_apps: true`, etc.) are intentional for CI coverage.

Every job runs with `permissions: contents: read`, set once at the workflow level. Without it jobs inherit the repository's `default_workflow_permissions`, which is `write` — so `bootstrap` (which pipes a curl'd script into bash) and `apply` (which executes this whole tree) were being handed a read/write `GITHUB_TOKEN` for no reason. Every checkout also sets `persist-credentials: false`, which matters most in `apply`, since it copies the checkout — `.git` included — into `~/.local/share/chezmoi`.

| Job | Runs on | What it gates |
|-----|---------|---------------|
| `lint` | macos + ubuntu | Five checks. **`zsh -n`** over `dot_zshrc`, `dot_zshenv`, every `*/*.zsh` and any zsh-shebang `bin/` script — see below. **`shellcheck`** (pinned v0.11.0, installed from upstream releases so both runners agree) over `install.sh`, `scripts/*.sh`, `bin/*`, `.chezmoiscripts/*.sh`, selected by shebang so `.ps1` and zsh files are skipped; plus every `.chezmoiscripts/**/*.tmpl` rendered through `chezmoi execute-template` first. **`py_compile`** over Python scripts, which shellcheck's shebang selection skips entirely. **`ruff`** (`E9,F,S`, ignoring `S603`/`S607`) over `bin/bump-deps` and `tests/python/` — `py_compile` only proves a file parses, so it cannot see a dead import. **`bump-deps --self-test`**. Strict — the tree was clean when each landed, so a new finding is a regression. |
| `workflows` | ubuntu | Audits the CI configuration itself, which nothing used to check. **`actionlint`** for correctness — and it runs shellcheck over `run:` blocks, ~200 lines of shell no other job sees. **`zizmor`** for security. Single-platform on purpose: `lint`/`test` are matrixed because the `.chezmoiscripts/{darwin,linux}` templates render per-OS, whereas workflow analysis is platform-independent. Ends with a **canary** — see below. |

**Why `zsh -n` is a separate gate.** shellcheck cannot parse zsh, so nothing else in CI looks at the ~25 files sourced into every interactive shell. That mattered more than it sounds: a parse error in a topic file does **not** hard-fail the shell — zsh reports it and carries on, silently dropping every alias and setting after the error. So a break would ship green and later present as "some of my aliases disappeared". The file list is derived from globs, not hardcoded, so a new topic file is covered automatically. `-n` parses without executing, which is the only safe option given these files alter `PATH`, install hooks and start the prompt.
| `test` | macos + ubuntu | `./tests/run` — bats over the shell, stdlib `unittest` over `bin/bump-deps`. bats-core is pinned to an exact release tarball **with its sha256 verified**, for the same reason shellcheck is pinned: Ubuntu's apt `bats` trails Homebrew's by several minors and they disagree about which helpers exist. Also asserts nothing **skipped** — a missing `jq`/`zsh`/`chezmoi` makes tests skip rather than fail (deliberate, so the suite runs on a half-configured laptop), but on a runner a skip means the job silently tested less than it claims. |
| `secrets` | ubuntu | `gitleaks` over full history (`fetch-depth: 0`). `GITLEAKS_ENABLE_COMMENTS: false` — the action posts PR comments by default, which needs `pull-requests: write`; the job already fails the build on a finding, so the comment adds nothing a red check doesn't. |
| `apply` | macos + ubuntu | Copies **the checkout** into `~/.local/share/chezmoi` and runs `install.sh`, then applies a second time and asserts no drift. |
| `bootstrap` | macos + ubuntu | Push-only. Tests the documented `curl \| bash` path, which necessarily clones `master` from GitHub, so it can only be meaningful post-merge. Needs `DOTFILES_FORCE_RESET=1`. |

**Why the `workflows` job ends with a canary.** zizmor's four most valuable audits — the ones that inspect a commit pin's provenance — are *online*: they need a `GH_TOKEN`. Without one they do not complain. zizmor reports nothing and exits 0, so a job that lost its token would keep going green while checking none of the supply-chain properties it was added for. `tests/fixtures/zizmor/canary.yml` pins a real commit under a deliberately wrong version comment, and the job fails unless `ref-version-mismatch` fires on it. Same reasoning as the `test` job's *Assert nothing was skipped* step. Do not "fix" that fixture's comment — correcting it turns the canary into a check that can never fail.

Three things worth preserving:

- **`apply` tests the checkout, not the remote.** It used to run `install_dotfiles.sh`, which clones `master` from GitHub and discards `actions/checkout` output entirely — so pull requests never tested their own code and fork PRs silently validated `master`.
- **The drift gate is `chezmoi status --exclude=scripts`, not `chezmoi verify`.** The four plain `run_after_` scripts are meant to run on every apply, so they are permanently "pending" and bare `chezmoi verify` can never exit 0.
- **`shellcheck` is installed twice** — in `lint`, and again in `workflows` where actionlint shells out to it. That is why its `bump-deps` pin uses `occurrences: "all"`. The alternative, ubuntu-latest's preinstalled shellcheck, is unpinned, which is the drift `lint` pins against in the first place.

CI cannot catch macOS-Homebrew-on-`PATH` bugs: GitHub's macOS runners ship Homebrew already on `PATH`, which is exactly why the Apple Silicon bootstrap could break undetected. Test that on a real clean machine or VM.
