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
- `.chezmoiscripts/darwin/run_onchange_before_10_homebrew.sh.tmpl` — installs Homebrew packages/casks (macOS only). Puts `brew` on `PATH` itself via a prefix-detection loop: `chezmoi apply` is not an interactive zsh, so it does not inherit what `homebrew/homebrew.zsh` sets, and on Apple Silicon `/opt/homebrew/bin` is not on the default `PATH`. It also exports `HOMEBREW_CASK_OPTS` (mirroring `homebrew/exports.zsh`) so apply-time cask installs get `--appdir=~/Applications` and `--require-sha`. Casks that upstream ships as `sha256 :no_check` cannot satisfy `--require-sha`, so they live in a separate `$casks_no_sha` list installed in a second pass with that flag dropped — keep that list as short as possible.
- `.chezmoiscripts/linux/` — parallel installs for Linux (apt-based, arm64)
- `.chezmoiscripts/darwin/run_after_20_zed_symlink.sh.tmpl` — symlinks Zed's CLI into `~/.local/bin/zed` (every apply, macOS only)
- `.chezmoiscripts/darwin/run_after_25_tailscale_cli.sh.tmpl` — puts Tailscale.app's CLI on `PATH` as `~/.local/bin/tailscale` via a small `exec` wrapper (not a symlink — the standalone Tailscale binary resolves its `.app` bundle from its launch path and panics through a symlink) (every apply, macOS only; no-op when Tailscale isn't installed)
- `.chezmoiscripts/run_after_30_asdf_completions.sh` — generates asdf zsh completions into `~/.asdf/completions` (every apply)
- `.chezmoiscripts/run_after_40_op_completions.sh` — generates 1Password CLI (`op`) zsh completions into `~/.cache/zsh/completions/_op`, only when `op` is installed (every apply; no-op otherwise, and `op` is not installed by this repo)
- `.chezmoiscripts/run_onchange_after_100_vim.sh.tmpl` — vim plugin setup
- `.chezmoiscripts/run_once_after_110_fix_git_upstream.sh.tmpl` — switches remote from HTTPS to SSH (runs once)

### External dependencies (`.chezmoiexternal.yaml`)
Chezmoi fetches these automatically (weekly refresh): vim-plug, zsh plugins (pure, autosuggestions, completions, history-substring-search, syntax-highlighting, zsh-z), and tmux plugins (tpm, resurrect, continuum, open, copycat, yank, themepack). They land in `~/.vim/`, `~/.local/zsh-plugins/`, and `~/.tmux/plugins/`.

**Every entry is pinned to a tag (or a commit, where upstream publishes no tags) and checksummed with `checksum.sha256`.** These files are sourced into every interactive shell and tmux session, so tracking `master` unverified meant anyone able to push to any one of those repos got automatic code execution here within the refresh period. Do not "simplify" an entry back to `master.tar.gz`.

Bumping is manual — Dependabot does not read this file:
```bash
curl -fsSL https://github.com/<owner>/<repo>/archive/<ref>.tar.gz | shasum -a 256
chezmoi apply --refresh-externals   # must exit 0
```
If *several* entries fail a checksum at once with unchanged refs, suspect GitHub regenerating its auto-archives (it has happened once, in 2023) rather than a compromise — verify, then recompute.

### Zsh loading order (`dot_zshrc`)
1. `*/exports.zsh` files — environment variables
2. `*/path.zsh` files — `$PATH` modifications
3. `zsh/prompt.zsh` — pure prompt
4. Plugins from `~/.local/zsh-plugins/` (order matters: syntax-highlighting before history-substring-search)
5. All remaining `*.zsh` files in topic directories (excluding `path.zsh`, `exports.zsh`, and `prompt.zsh`, already loaded above)
6. `~/.localrc` if present (machine-local secrets, not tracked)

Completion caches live under `$XDG_CACHE_HOME/zsh/` (`zcompdump`, `zcompcache/`), not in `$HOME`. `compinit` is invoked with an explicit `-d` for that reason; if you change the path, change it in both `dot_zshrc` and `zsh/completion.zsh`.

`TERM` is deliberately **not** set anywhere. Ghostty, tmux (`dot_tmux.conf` sets `tmux-256color`) and herdr each set it correctly; a blanket `export TERM=xterm-256color` used to overwrite all three. If an ssh target lacks a terminfo entry, fix it there (`infocmp -x | ssh host -- tic -x -`) or set `term =` in `dot_config/ghostty/config`.

Startup performance: `dot_zshrc` defines a `cached-eval` helper that caches the output of `eval "$(cmd init ...)"` style hooks in `~/.cache/zsh/` and re-runs the command only when the tool's binary is newer than the cache (used by `atuin/atuin.zsh` and `homebrew/homebrew.zsh`). Prefer `cached-eval <cache-name> <cmd> <args...>` over `eval "$(...)"` for new integrations, zsh builtin parameters (`$OSTYPE`, `$HOST`, `$TTY`, `$commands[...]`) over `$(uname)`/`$(tty)`/`$(which ...)` forks, and chezmoi apply-time scripts over per-shell setup work.

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
- `git-*` — custom git subcommands: `backup-branch`, `checkout-default-branch`, `clean-submodules`, `copy-branch-name`, `delete-local-merged`, `nuke`, `promote`, `track`, `unpushed`, `unpushed-stat`, `up`
- `secret` — Keychain CRUD wrapper around macOS `security` (`set`/`get`/`rotate`/`rm` generic-password secrets; account defaults to `$USER`, override with `$SECRET_ACCOUNT`). Also provides the **env bundle** (`env` / `env-edit` / `env-import`) — see below.
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
- `.claude/`, `.github/`, `.vscode/`, `scripts/`, `install.sh`, and the docs

### Hand-applied config — do not judge these by "is anything referencing it?"

Some files here are reference material that a human imports by hand. Nothing in the repo invokes them, so a grep for references finds nothing and they *look* dead. They are not. Before deleting anything on "unreferenced" grounds, check whether it belongs in this category — a repo-wide grep cannot distinguish "dead" from "applied manually".

- `terminal/MATE.terminal` — a **dconf dump** (starts `[global]`), for the MATE/GNOME terminal on Linux desktops:
  ```bash
  dconf load /org/mate/terminal/ < terminal/MATE.terminal
  ```
- `terminal/Monokai.terminal` — an Apple **plist**, a profile for macOS's native Terminal.app. Import via Terminal → Settings → Profiles → Import, or `open terminal/Monokai.terminal`.

Both are live. `MATE.terminal` was previously *also* loaded automatically by the Parrot bootstrap script; retiring Parrot removed that one automated caller but not the file's purpose.

Note: `dot_config/zed/settings.json` (managed by chezmoi) is Zed's editor config, applied to `~/.config/zed/settings.json`; the Zed CLI symlink is handled by `.chezmoiscripts/darwin/run_after_20_zed_symlink.sh.tmpl`. `dot_config/ghostty/config` (managed by chezmoi) is Ghostty's terminal config, applied to `~/.config/ghostty/config`. `dot_config/herdr/config.toml` (managed by chezmoi) is herdr's config, applied to `~/.config/herdr/config.toml`.

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

### `dot_gitignore` vs `.gitignore`
Two gitignore files coexist in this repo. `dot_gitignore` is managed by chezmoi and becomes `~/.gitignore` (the global gitignore). `.gitignore` is the repo's own gitignore and only excludes `system/linux.zsh`. When editing the global gitignore, use `dot_gitignore`.

### Go template notes
- `{{-` strips leading whitespace; `-}}` strips trailing whitespace
- OS detection pattern: `.chezmoi.os` (`"darwin"` / `"linux"`) and `.chezmoi.osRelease.id`
- Scripts guarded by `{{- if (eq .chezmoi.os "darwin") -}}` are no-ops on other platforms

## CI

`.github/workflows/ci.yaml` has four jobs. The non-interactive template defaults (`install_mac_apps: true`, etc.) are intentional for CI coverage.

| Job | Runs on | What it gates |
|-----|---------|---------------|
| `lint` | ubuntu | `shellcheck` over `install.sh`, `scripts/*.sh`, `bin/*` (selected by shebang, so `.ps1` and the zsh script are skipped), plus every `.chezmoiscripts/**/*.tmpl` rendered through `chezmoi execute-template` first. Strict — the tree was clean when this landed, so a new finding is a regression. |
| `secrets` | ubuntu | `gitleaks` over full history (`fetch-depth: 0`). |
| `apply` | macos + ubuntu | Copies **the checkout** into `~/.local/share/chezmoi` and runs `install.sh`, then applies a second time and asserts no drift. |
| `bootstrap` | macos + ubuntu | Push-only. Tests the documented `curl \| bash` path, which necessarily clones `master` from GitHub, so it can only be meaningful post-merge. Needs `DOTFILES_FORCE_RESET=1`. |

Two things worth preserving:

- **`apply` tests the checkout, not the remote.** It used to run `install_dotfiles.sh`, which clones `master` from GitHub and discards `actions/checkout` output entirely — so pull requests never tested their own code and fork PRs silently validated `master`.
- **The drift gate is `chezmoi status --exclude=scripts`, not `chezmoi verify`.** The four plain `run_after_` scripts are meant to run on every apply, so they are permanently "pending" and bare `chezmoi verify` can never exit 0.

CI cannot catch macOS-Homebrew-on-`PATH` bugs: GitHub's macOS runners ship Homebrew already on `PATH`, which is exactly why the Apple Silicon bootstrap could break undetected. Test that on a real clean machine or VM.
