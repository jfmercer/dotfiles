#!/bin/bash

rm ~/.gitconfig
rm ~/.gitignore
rm ~/.hushlogin
rm ~/.spacemacs
rm ~/.tmux.conf
rm -r ~/.vim
rm ~/.vimrc
rm -r ~/.config/yarn
rm ~/.zshenv
rm ~/.zshrc

if [ "$(uname -s)" == "Darwin" ]; then
  rm -r ~/.cider
  rm -r ~/.config/karabiner
fi
