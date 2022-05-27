#!/bin/bash

ZPLUGINDIR=$HOME/.dotfiles/plugins/bundle

if [[ ! -d $ZPLUGINDIR/pure ]]; then
  git clone https://github.com/sindresorhus/pure $ZPLUGINDIR/pure
fi
if [[ ! -d $ZPLUGINDIR/zsh-autosuggestions ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions $ZPLUGINDIR/zsh-autosuggestions
fi
if [[ ! -d $ZPLUGINDIR/zsh-completions ]]; then
  git clone https://github.com/zsh-users/zsh-completions $ZPLUGINDIR/zsh-completions
fi
if [[ ! -d $ZPLUGINDIR/zsh-history-substring-search ]]; then
  git clone https://github.com/zsh-users/zsh-history-substring-search $ZPLUGINDIR/zsh-history-substring-search
fi
if [[ ! -d $ZPLUGINDIR/zsh-syntax-highlighting ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZPLUGINDIR/zsh-syntax-highlighting
fi
if [[ ! -d $ZPLUGINDIR/zsh-z ]]; then
  git clone https://github.com/agkozak/zsh-z $ZPLUGINDIR/zsh-z
fi
