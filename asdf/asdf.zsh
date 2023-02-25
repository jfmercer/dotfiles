# Cheap hack to get $PATH to work for custom homebrew dir
# See homebrew.zsh for asdf getting loaded in that situation
# asdf needs to be before homebrew in the $PATH
#
# Please see homebrew/homebrew.zsh for more sadness
#
if [ ! -d "$HOME/homebrew" ] && [ ! -d "/home/linuxbrew/" ]; then
    . $HOME/.asdf/asdf.sh
fi

# append completions to fpath
fpath=(${ASDF_DIR}/completions $fpath)
# compinit happens in zshrc and is not needed here
