#!/bin/bash

# Install `brew` in $HOME rather than /usr/local
git clone https://github.com/Homebrew/brew "$HOME"/homebrew
eval "$HOME/homebrew/bin/brew shellenv"
brew update --force --quiet
chmod -R go-w "$(brew --prefix)/share/zsh"
