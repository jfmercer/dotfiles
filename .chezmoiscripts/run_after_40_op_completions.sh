#!/usr/bin/env bash

# Generate 1Password CLI (op) zsh completions at `chezmoi apply` time instead of
# shell startup. op is not installed by this repo — this is a no-op unless the
# user has installed op on this machine. The shared completions dir is added to
# fpath in dot_zshrc; compinit (also in dot_zshrc) lazy-loads the _op file.
if command -v op >/dev/null 2>&1; then
    completions_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
    mkdir -p "$completions_dir"
    op completion zsh > "$completions_dir/_op"
fi
