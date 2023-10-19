# initialize homebrew
if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS $HOME dir custom install
    if [ -d "$HOME/homebrew" ]; then
        eval "$($HOME/homebrew/bin/brew shellenv)"
        # Put asdf before homebrew in $PATH when homebrew is in $HOME/homebrew
        . $HOME/.asdf/asdf.sh
    # standard macOS install
    else
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi
