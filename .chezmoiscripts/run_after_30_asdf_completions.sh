#!/usr/bin/env bash

# Generate asdf's zsh completions at apply time instead of shell startup.
# asdf/asdf.zsh adds this directory to fpath.
if command -v asdf >/dev/null 2>&1; then
    completions_dir="${ASDF_DATA_DIR:-$HOME/.asdf}/completions"
    mkdir -p "$completions_dir"
    asdf completion zsh > "$completions_dir/_asdf"
fi
