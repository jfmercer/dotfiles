# matches case insensitive for lowercase
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# pasting with tabs doesn't perform completion
zstyle ':completion:*' insert-tab pending

# Caching = speed. Regenerable cache, so keep it under $XDG_CACHE_HOME with the
# compinit dump (see dot_zshrc) instead of in $HOME.
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache

# Look at
# https://github.com/sorin-ionescu/prezto/blob/master/modules/completion/init.zsh
#
