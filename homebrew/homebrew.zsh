# initialize homebrew
# macOS $HOME dir custom install
if [ -d "$HOME/homebrew" ]; then
    eval "$HOME/homebrew/bin/brew shellenv"
# linuxbrew install
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# standard macOS install
else
    eval "$(/usr/local/bin/brew shellenv)"
fi
