# zsh auto completions. This assumes that Homebrew has
# already installed zsh-completions
zsh_completion='$(brew --prefix)/share/zsh-completions'

if test -f $zsh_completion
then
  source $zsh_completion
fi
