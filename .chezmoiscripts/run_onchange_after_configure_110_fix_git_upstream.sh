#!/usr/bin/env bash

set -eufo pipefail

DOTFILES_HOME="$HOME/.local/share/chezmoi"
DOTFILES_SSH_ORIGIN="git@github.com:jfmercer/dotfiles.git"

cd "$DOTFILES_HOME" || ( echo "fix_git_upstream could not find dotfiles directory!"; exit 1 )

echo "Changing git repo upstream from HTTPS to SSH"
echo "Old upstream:"
git remote -v
git remote rm origin
git remote add origin "$DOTFILES_SSH_ORIGIN"
EXIT_CODE=$?
echo "New upstream:"
git remote -v

cd - || ( echo "fix_git_upstream could not cd back to original directory!"; exit 1 )

exit $EXIT_CODE
