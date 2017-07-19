#!/bin/sh
if [ "$(uname -s)" == "Darwin" ]; then
  echo "Setting up iTerm2"
  defaults write com.googlecode.iterm2 "PrefsCustomFolder" -string "$DOTFILES/iterm2"
  defaults write com.googlecode.iterm2 "LoadPrefsFromCustomFolder" -bool true
else
  echo "Not a Mac; therefore, iTerm2 settings are not used."
fi