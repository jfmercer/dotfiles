#!/bin/bash

# force link
# -f for files
# -fF for directories

ln -sfF ~/.dotfiles/alacritty ~/.config/alacritty
ln -sf ~/.dotfiles/git/gitconfig ~/.gitconfig
ln -sf ~/.dotfiles/git/gitignore ~/.gitignore
ln -sf ~/.dotfiles/zsh/hushlogin ~/.hushlogin
# ln -sf ~/.dotfiles/emacs/.spacemacs ~/.spacemacs
ln -sf ~/.dotfiles/ruby/gemrc ~/.gemrc
ln -sf ~/.dotfiles/tmux/tmux.conf ~/.tmux.conf
ln -sfF ~/.dotfiles/vim ~/.vim
ln -sf ~/.dotfiles/vim/vimrc ~/.vimrc
ln -sf ~/.dotfiles/zsh/zshenv ~/.zshenv
ln -sf ~/.dotfiles/zsh/zshrc ~/.zshrc

if [ "$(uname -s)" == "Darwin" ]; then
  ln -sfF ~/.dotfiles/cider ~/.cider
  ln -sfF ~/.dotfiles/karabiner ~/.config/karabiner
fi
