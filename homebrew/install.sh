#!/bin/bash

# Install `brew` in $HOME rather than /usr/local
cd $HOME
git clone https://github.com/Homebrew/brew homebrew
eval "$HOME/homebrew/bin/brew shellenv"
brew update --force --quiet
chmod -R go-w "$(brew --prefix)/share/zsh"
