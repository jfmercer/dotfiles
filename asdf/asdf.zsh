# https://asdf-vm.com/guide/getting-started.html#_1-install-asdf

completions_dir="${ASDF_DATA_DIR:-$HOME/.asdf}/completions"
asdf_completion_file="${completions_dir}/_asdf"

if [[ ! -d "$completions_dir" ]]; then
  mkdir -p "$completions_dir"
fi

if [[ ! -f "$asdf_completion_file" ]]; then
  asdf completion zsh > "$asdf_completion_file"
fi

# append completions to fpath
fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)
# compinit happens in zshrc and is not needed here
