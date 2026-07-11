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
Prompts for `email`, `install_mac_apps`, `install_linux_apps`, and `set_git_to_ssh` at init time. These are available in templates as `.email`, `.install_mac_apps`, etc. In CI they default to `true`.

### Script lifecycle
Scripts in `.chezmoiscripts/` root run on all platforms; those in `darwin/` or `linux/` subdirs run only on that platform.
- `.chezmoiscripts/darwin/run_onchange_before_10_homebrew.sh.tmpl` — installs Homebrew packages/casks (macOS only)
- `.chezmoiscripts/linux/` — parallel installs for Linux (apt-based, Parrot OS, arm64)
- `.chezmoiscripts/darwin/run_after_20_zed_symlink.sh.tmpl` — symlinks Zed's CLI into `~/.local/bin/zed` (every apply, macOS only)
- `.chezmoiscripts/run_after_30_asdf_completions.sh` — generates asdf zsh completions into `~/.asdf/completions` (every apply)
- `.chezmoiscripts/run_onchange_after_100_vim.sh.tmpl` — vim plugin setup
- `.chezmoiscripts/run_once_after_110_fix_git_upstream.sh.tmpl` — switches remote from HTTPS to SSH (runs once)

### External dependencies (`.chezmoiexternal.yaml`)
Chezmoi fetches these automatically (weekly refresh): vim-plug, zsh plugins (pure, autosuggestions, completions, history-substring-search, syntax-highlighting, zsh-z), and tmux plugins (tpm, resurrect, continuum, open, copycat, yank, themepack). They land in `~/.vim/`, `~/.local/zsh-plugins/`, and `~/.tmux/plugins/`.

### Zsh loading order (`dot_zshrc`)
1. `*/exports.zsh` files — environment variables
2. `*/path.zsh` files — `$PATH` modifications
3. `zsh/prompt.zsh` — pure prompt
4. Plugins from `~/.local/zsh-plugins/` (order matters: syntax-highlighting before history-substring-search)
5. All remaining `*.zsh` files in topic directories (excluding `path.zsh`, `exports.zsh`, and `prompt.zsh`, already loaded above)
6. `~/.localrc` if present (machine-local secrets, not tracked)

Startup performance: `dot_zshrc` defines a `cached-eval` helper that caches the output of `eval "$(cmd init ...)"` style hooks in `~/.cache/zsh/` and re-runs the command only when the tool's binary is newer than the cache (used by `atuin/atuin.zsh` and `homebrew/homebrew.zsh`). Prefer `cached-eval <cache-name> <cmd> <args...>` over `eval "$(...)"` for new integrations, zsh builtin parameters (`$OSTYPE`, `$HOST`, `$TTY`, `$commands[...]`) over `$(uname)`/`$(tty)`/`$(which ...)` forks, and chezmoi apply-time scripts over per-shell setup work.

### Topical organization
Each tool/concern has its own directory with `.zsh` files:
- `exports.zsh` — env vars
- `path.zsh` — PATH additions
- `alii.zsh` — aliases
- `*.zsh` — everything else

Active topics: `asdf`, `atuin`, `fzf`, `git`, `gpg`, `homebrew`, `kali`, `macos`, `rust`, `system`, `vagrant`, `zsh`.

### `bin/` scripts
Custom executables that run in-place from the chezmoi source directory. `system/path.zsh` adds `$DOTFILES/bin` to `$PATH`, so nothing is copied or symlinked elsewhere. Before adding a new script, check here first:
- `bupdate` — `brew update && brew upgrade && brew cleanup`
- `git-*` — custom git subcommands: `backup-branch`, `checkout-default-branch`, `clean-submodules`, `copy-branch-name`, `delete-local-merged`, `nuke`, `promote`, `track`, `unpushed`, `unpushed-stat`, `up`
- `secret` — Keychain CRUD wrapper around macOS `security` (`set`/`get`/`rotate`/`rm` generic-password secrets; account defaults to `$USER`, override with `$SECRET_ACCOUNT`)
- `enum`, `makeEnv` — misc utilities
- `start-bloodhound`, `tun0.sh`, `pycharm` — security/tool launchers
- `ps*.ps1` — PowerShell helpers (Base64 encode, reverse shell scaffold)
- `time-startup` — times 10 interactive zsh startups
- `update-discord` — downloads and installs the latest Discord .deb (Linux)

### Unmanaged directories
All directories without a `dot_`, `run_`, or `empty_` prefix are unmanaged — chezmoi never applies them to `$HOME`. They are listed in `.chezmoiignore` to suppress warnings.

**Topic directories** — contain `.zsh` files sourced directly from the chezmoi source directory by `dot_zshrc` (see Zsh loading order above). None are applied to `$HOME` by chezmoi.
`asdf/`, `atuin/`, `fzf/`, `git/`, `gpg/`, `homebrew/`, `kali/`, `macos/`, `rust/`, `system/`, `vagrant/`, `zsh/`

**Tooling/meta:**
- `.claude/` — Claude Code config (this directory)
- `.github/` — GitHub Actions CI workflows
- `.vscode/` — VS Code workspace settings
- `scripts/` — bootstrap and install scripts

**App configs** (installed manually or via their own install scripts):
- `bin/` — custom executables (see bin/ scripts above)
- `iterm2/` — iTerm2 plist + `install.sh`
- `terminal/` — macOS Terminal.app profiles (MATE, Monokai)

Note: `dot_config/zed/settings.json` (managed by chezmoi) is Zed's editor config, applied to `~/.config/zed/settings.json`; the Zed CLI symlink is handled by `.chezmoiscripts/darwin/run_after_20_zed_symlink.sh.tmpl`. `dot_config/ghostty/config` (managed by chezmoi) is Ghostty's terminal config, applied to `~/.config/ghostty/config`.

### `dot_gitignore` vs `.gitignore`
Two gitignore files coexist in this repo. `dot_gitignore` is managed by chezmoi and becomes `~/.gitignore` (the global gitignore). `.gitignore` is the repo's own gitignore and only excludes `system/linux.zsh`. When editing the global gitignore, use `dot_gitignore`.

### Go template notes
- `{{-` strips leading whitespace; `-}}` strips trailing whitespace
- OS detection pattern: `.chezmoi.os` (`"darwin"` / `"linux"`) and `.chezmoi.osRelease.id`
- Scripts guarded by `{{- if (eq .chezmoi.os "darwin") -}}` are no-ops on other platforms

## CI

GitHub Actions (`.github/workflows/ci.yaml`) runs `scripts/install_dotfiles.sh` on both `macos-latest` and `ubuntu-latest` on every push/PR to master. The non-interactive defaults (`install_mac_apps: true`, etc.) are intentional for CI coverage.
