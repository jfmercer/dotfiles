# My Dotfiles
These are my dotfiles, managed by [chezmoi](https://github.com/twpayne/chezmoi).

## Getting started

You can use the [convenience script](./scripts/install_dotfiles.sh) to install the dotfiles on any machine with a single command. Simply run one of the following commands in your terminal:

`wget`
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/jfmercer/dotfiles/master/scripts/install_dotfiles.sh)"
```

`curl`:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jfmercer/dotfiles/master/scripts/install_dotfiles.sh)"
```
## Convenience script

The [getting started](#getting-started) step used the [convenience script](./scripts/install_dotfiles.sh) to install this dotfiles. There are some extra options that you can use to tweak the installation if you need.

It supports some environment variables:

- `DOTFILES_REPO_HOST`: Defaults to `https://github.com`.
- `DOTFILES_USER`: Defaults to `jfmercer`.
- `DOTFILES_BRANCH`: Defaults to `master`.
- `DOTFILES_FORCE_RESET`: Unset by default. When the source directory already exists, the installer does a fast-forward-only pull and **refuses to run if there are local changes**. Set this to `1` to discard local commits and untracked files instead (`git reset --hard` + `git clean -fdx`). Used by CI, which wants a clean slate.

For example, you can use it to clone and install the dotfiles repository at the `beta` branch with:

```console
DOTFILES_BRANCH=foobar /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/jfmercer/dotfiles/master/scripts/install_dotfiles.sh)"
```

## What the install command trusts

The `curl | bash` one-liner above executes code fetched over the network before you have read it. Specifically it trusts:

- `raw.githubusercontent.com` to serve an honest `scripts/install_dotfiles.sh`,
- `get.chezmoi.io` to serve an honest chezmoi installer — the version it installs is pinned in `install.sh`, so a compromised endpoint cannot silently substitute a different chezmoi, but the installer script itself is unpinned,
- Homebrew's `install.sh` from `HEAD` (macOS only).

Everything downstream of that *is* pinned and verified: all `.chezmoiexternal.yaml` entries carry a `checksum.sha256`, and the Linux install script verifies `rustup-init`'s checksum, lazygit's release checksum, and the eza signing key's fingerprint before using any of them. rustup is pinned by version and fetched from its immutable `archive/<version>/` path rather than through `sh.rustup.rs`, which is unversioned and does not itself verify the binary it downloads.

If that residual trust is not acceptable, clone the repo over SSH and run `./install.sh` directly instead of piping anything into a shell.

## Troubleshooting

### Debug Installation
Add `DOTFILES_DEBUG=true` to get debug output during the installation.

## nvim

Neovim is the default editor: `$VISUAL`/`$EDITOR`, git's `core.editor`, and the
`v` / `ev` / `egc` / `egi` aliases all invoke `nvim`. Its config is the
[LazyVim](https://www.lazyvim.org/) starter in `dot_config/nvim/`, with two
local changes — the leader is `,` (not LazyVim's space) and `jk` is `ESC` in
insert mode. `ev` opens the config; project work still happens in Zed
(`c` / `erc`).

## vim

Still installed, still configured as below, but nothing points at it by default
any more — type `vim` to get it. Its config is entirely separate from Neovim's:
nvim does not read `~/.vimrc`, and `~/.vim` is not on its `runtimepath`.

#### Key Mappings

* `ESC` is now `jk`. This will save your left pinky from a premature death.
* `F2` toggles paste.
* `F3` toggles NERDTree.
* `,ev` edits your vimrc. The mnemonic is 'e'dit 'v'imrc.
* `,sv` sources your vimrc. The mnemonic is 's'ource 'v'imrc.

The `,ev` / `,sv` mappings above are vim's own, and still reach `~/.vimrc`. The
shell alias `ev` is a different thing: it now opens Neovim's config.

### Plugins

##### [Fugitive](https://github.com/tpope/vim-fugitive)
To quote Tim Pope, it's "a Git wrapper so awesome, it should be illegal."
##### [Surround](https://github.com/tpope/vim-surround)
This handles the surrounding of text objects with parentheses, brackets, quotes, tags, etc.
Use `cs`, `ds`, `ys`, & `yss`. See [the documentation](https://github.com/tpope/vim-surround#surroundvim) or run `:help surround`.
##### [NERDTree](https://github.com/scrooloose/nerdtree)
A file tree explorer. Basically, the project drawer you may be missing from Textmate and Sublime Text.
##### [NERD Commenter](https://github.com/scrooloose/nerdcommenter)
This makes commenting much easier. Select something, `[count]<leader>cc`, done.
##### [Easy Motion](https://github.com/Lokaltog/vim-easymotion)
Easy Motion makes it much, much easier to move the cursor around the screen. See @Lokaltog's [introduction](https://github.com/Lokaltog/vim-easymotion#introduction) for details. The short version: hit `<Leader><Leader>` followed by a motion key (say, `<Leader><Leader>w`) and then watch the magic happen.
##### [vim-airline](https://github.com/bling/vim-airline)
A beautiful and very useful vim status line. For this to work properly, you may have to install Powerline-ready fonts, four of which [may be found here](https://github.com/jfmercer/mad/tree/master/fonts).
##### [vim-monokai](https://github.com/sickill/vim-monokai)
Adds the monokai color scheme.
##### [delimitMate](https://github.com/Raimondi/delimitMate)
Provides insert mode auto-completion for quotes, parentheses, brackets, etc.

### A Note on Go Templates

Apparently, `{{-` strips leading whitespace, `-}}` strips trailing whitespace, and both `{{` and `}}` do neither.

## Credits

I have borrowed heavily from the following:
* [Zach Holman](https://github.com/holman/dotfiles) - I borrow his topical organization scheme
* [Mathias Bynens](https://github.com/mathiasbynens/dotfiles) - mainly for his legendary .macos script
* [Felipe Santos](https://github.com/felipecrs/dotfiles) - chezmoi inspiration
* [Mike Kasberg](https://github.com/mkasberg/dotfiles) - chezmoi inspiration
* [Tom Payne](https://github.com/twpayne/dotfiles) - chezmoi inspiration
