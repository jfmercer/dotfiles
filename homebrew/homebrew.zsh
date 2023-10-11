# initialize homebrew
# macOS $HOME dir custom install
if [ -d "$HOME/homebrew" ]; then
    eval "$($HOME/homebrew/bin/brew shellenv)"
    # Put asdf before homebrew in $PATH when homebrew is in $HOME/homebrew
    . $HOME/.asdf/asdf.sh
# linuxbrew install
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    # Put asdf before homebrew in $PATH on linuxbrew
    . $HOME/.asdf/asdf.sh
# standard macOS install
else
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
