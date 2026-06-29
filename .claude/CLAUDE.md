# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [chezmoi](https://github.com/twpayne/chezmoi)-managed dotfiles repository. The source directory lives at `~/.local/share/chezmoi`; chezmoi applies it to `$HOME`.

## Key commands

```bash
chezmoi apply          # apply changes from source to home directory
chezmoi diff           # preview what apply would change (uses delta)
chezmoi add <file>     # track a new file from $HOME into this repo
chezmoi edit <file>    # edit a tracked file in the source directory
chezmoi cd             # cd into the source directory
```

Apply to a fresh machine (one-liner):
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jfmercer/dotfiles/master/scripts/install_dotfiles.sh)"
```

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
- `.chezmoiscripts/darwin/run_onchange_before_10_homebrew.sh.tmpl` — installs Homebrew packages/casks when the script content changes
- `.chezmoiscripts/linux/` — parallel installs for Linux (apt-based, Parrot OS, arm64)
- `.chezmoiscripts/run_onchange_after_100_vim.sh.tmpl` — vim plugin setup
- `.chezmoiscripts/run_once_after_110_fix_git_upstream.sh.tmpl` — switches remote from HTTPS to SSH (runs once)

### External dependencies (`.chezmoiexternal.yaml`)
Chezmoi fetches these automatically (weekly refresh): vim-plug, zsh plugins (pure, autosuggestions, completions, history-substring-search, syntax-highlighting, zsh-z), and tmux plugins (tpm, resurrect, continuum, open, copycat, yank, themepack). They land in `~/.vim/`, `~/.local/zsh-plugins/`, and `~/.tmux/plugins/`.

### Zsh loading order (`dot_zshrc`)
1. `*/exports.zsh` files — environment variables
2. `*/path.zsh` files — `$PATH` modifications
3. `zsh/prompt.zsh` — pure prompt
4. Plugins from `~/.local/zsh-plugins/` (order matters: syntax-highlighting before history-substring-search)
5. All remaining `*.zsh` files in topic directories
6. `~/.localrc` if present (machine-local secrets, not tracked)

### Topical organization
Each tool/concern has its own directory with `.zsh` files:
- `exports.zsh` — env vars
- `path.zsh` — PATH additions
- `alii.zsh` — aliases
- `*.zsh` — everything else

Active topics: `asdf`, `atuin`, `fzf`, `git`, `gpg`, `homebrew`, `kali`, `macos`, `navi`, `rust`, `system`, `zsh`.

### Go template notes
- `{{-` strips leading whitespace; `-}}` strips trailing whitespace
- OS detection pattern: `.chezmoi.os` (`"darwin"` / `"linux"`) and `.chezmoi.osRelease.id`
- Scripts guarded by `{{- if (eq .chezmoi.os "darwin") -}}` are no-ops on other platforms

## CI

GitHub Actions (`.github/workflows/ci.yaml`) runs `scripts/install_dotfiles.sh` on both `macos-latest` and `ubuntu-latest` on every push/PR to master. The non-interactive defaults (`install_mac_apps: true`, etc.) are intentional for CI coverage.
