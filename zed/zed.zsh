ZED_APP="$HOME/Applications/Zed.app"
ZED_CLI="$ZED_APP/Contents/MacOS/cli"
LINK_TARGET="$HOME/.local/bin/zed"

if [[ "$(uname)" == "Darwin" ]] && [[ -d "$ZED_APP" ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$ZED_CLI" "$LINK_TARGET"
fi