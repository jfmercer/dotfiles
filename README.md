# My Dotfiles
These are my dotfiles, managed by [chezmoi](https://github.com/twpayne/chezmoi).

## Getting started

You can use the [convenience script](./scripts/install_dotfiles.sh) to install the dotfiles on any machine with a single command. Simply run one of the following commands in your terminal:

`wget`
```bash
sh -c "$(wget -qO- https://raw.githubusercontent.com/jfmercer/dotfiles/master/scripts/install_dotfiles.sh)"
```

`curl`:
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/jfmercer/dotfiles/master/scripts/install_dotfiles.sh)"
```

## vim
#### Key Mappings

* `ESC` is now `jk`. This will save your left pinky from a premature death.
* `F2` toggles paste.
* `F3` toggles NERDTree.
* `F4` toggles tagbar.
* `,ev` edits your vimrc. The mnemonic is 'e'dit 'v'imrc.
* `,sv` sources your vimrc. The mnemonic is 's'ource 'v'imrc.

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
##### [Tagbar](https://github.com/majutsushi/tagbar)
Tagbar is for browsing the tags of source code files. It needs to have [Exuberant ctags](http://ctags.sourceforge.net/) installed in order to work.
##### [Syntastic](https://github.com/scrooloose/syntastic)
Syntastic brings syntax checking to vim. As soon as you save a file, syntastic will check it for syntax errors and list them on the left-hand column. Note that it works with supported syntax checks, and if these are not installed, it won't work. For example, for Python, you need to have `flake8`, `pyflakes`, or `pylint` in your `$PATH`. Jump between errors with `:lnext` and `:lprev`.
##### [Easy Motion](https://github.com/Lokaltog/vim-easymotion)
Easy Motion makes it much, much easier to move the cursor around the screen. See @Lokaltog's [introduction](https://github.com/Lokaltog/vim-easymotion#introduction) for details. The short version: hit `<Leader><Leader>` followed by a motion key (say, `<Leader><Leader>w`) and then watch the magic happen.
##### [vim-airline](https://github.com/bling/vim-airline)
A beautiful and very useful vim status line. For this to work properly, you may have to install Powerline-ready fonts, four of which [may be found here](https://github.com/jfmercer/mad/tree/master/fonts).
##### [vim-monokai](https://github.com/sickill/vim-monokai)
Adds the monokai color scheme.
##### [delimitMate](https://github.com/Raimondi/delimitMate)
Provides insert mode auto-completion for quotes, parentheses, brackets, etc.

## Credits

I have borrowed heavily from the following:
* [Zach Holman](https://github.com/holman/dotfiles) - I borrow his topical organization scheme
* [Mathias Bynens](https://github.com/mathiasbynens/dotfiles) - mainly for his legendary .macos script
* [Felipe Santos](https://github.com/felipecrs/dotfiles) - chezmoi inspiration
* [Mike Kasberg](https://github.com/mkasberg/dotfiles) - chezmoi inspiration
* [Tom Payne](https://github.com/twpayne/dotfiles) - chezmoi inspiration
