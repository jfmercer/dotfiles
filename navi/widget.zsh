if command -v navi >/dev/null 2>&1; then
    eval "$(navi widget zsh)"
else
    echo "navi is not installed"
fi
