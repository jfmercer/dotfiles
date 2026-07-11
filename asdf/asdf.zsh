# completions are generated at `chezmoi apply` time
# (see .chezmoiscripts/run_after_30_asdf_completions.sh)
fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)
# compinit happens in zshrc and is not needed here
