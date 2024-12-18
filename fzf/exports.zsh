# Taken from https://gist.github.com/jfmercer/4417f4e4a0f887d34d1a9fc83d11d16b

FD_OPTIONS="--follow --exclude .git --exclude node_modules"
# with file preview
# export FZF_DEFAULT_OPTS="--no-mouse --height 90% -1 --reverse --multi --inline-info --preview='[[ \$(file --mime {}) =~ binary ]] && echo {} is a binary file || (bat --style=numbers --color=always {} || cat {}) 2> /dev/null | head -300'"
# without file preview
export FZF_DEFAULT_OPTS="--no-mouse --height 90% -1 --reverse --multi --inline-info"

# Use git ls-files inside git repo, otherwise fd
export FZF_DEFAULT_COMMAND="git ls-files --cached --others --exclude-standard | fd --type f --type l $FD_OPTIONS"
export FZF_CTRL_T_COMMAND="fd $FD_OPTIONS"
export FZF_ALT_C_COMMAND="fd --type d $FD_OPTIONS"

# On Linux, we need fdfind instead of fd and batcat instead of bat.
if [[ "$(uname)" == "Linux" ]]; then
    # with file preview
    # export FZF_DEFAULT_OPTS="--no-mouse --height 90% -1 --reverse --multi --inline-info --preview='[[ \$(file --mime {}) =~ binary ]] && echo {} is a binary file || (batcat --style=numbers --color=always {} || cat {}) 2> /dev/null | head -300'"
    # without file preview
    export FZF_DEFAULT_OPTS="--no-mouse --height 90% -1 --reverse --multi --inline-info"
    export FZF_DEFAULT_COMMAND="git ls-files --cached --others --exclude-standard | fdfind --type f --type l $FD_OPTIONS"
    export FZF_CTRL_T_COMMAND="fdfind $FD_OPTIONS"
    export FZF_ALT_C_COMMAND="fdfind --type d $FD_OPTIONS"
fi
