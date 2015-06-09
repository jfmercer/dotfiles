# fish style history substring search. This assumes that Homebrew has
# already installed zsh-history-substring-search

# NOTE: zsh-syntax-highlighting must be sourced before this one.
zsh_history_substring_search='$(brew --prefix)/opt/zsh-history-substring-search/zsh-history-substring-search.zsh'

if test -f $zsh_history_substring_search
then
  source $zsh_history_substring_search
fi
