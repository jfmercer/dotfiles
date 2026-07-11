# initialize homebrew from a cached copy of `brew shellenv`
# (see cached-eval in dot_zshrc)
if [[ -x /opt/homebrew/bin/brew ]]; then
  cached-eval brew-shellenv /opt/homebrew/bin/brew shellenv
fi
