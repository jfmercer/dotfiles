#!/bin/bash

ZPLUGINDIR=$HOME/.dotfiles/plugins/bundle

cd $ZPLUGINDIR
find . -maxdepth 1 -type d \( ! -name . \) -exec bash -c "cd '{}' && git pull" \;
cd -
