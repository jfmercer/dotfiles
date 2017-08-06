# NOTE: zsh-completions loaded via antibody

# matches case insensitive for lowercase
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# pasting with tabs doesn't perform completion
zstyle ':completion:*' insert-tab pending

# Caching = speed
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $HOME/.zcompcache

# Look at
# https://github.com/sorin-ionescu/prezto/blob/master/modules/completion/init.zsh
#
