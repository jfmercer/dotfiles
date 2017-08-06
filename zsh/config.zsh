HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000


setopt NO_BG_NICE # don't nice background tasks
setopt NO_HUP
setopt NO_LIST_BEEP
setopt LOCAL_OPTIONS # allow functions to have local options
setopt LOCAL_TRAPS # allow functions to have local traps
setopt EXTENDED_HISTORY # add timestamps to history
setopt PROMPT_SUBST
setopt CORRECT # correct commands
setopt COMPLETE_IN_WORD
setopt APPEND_HISTORY # adds history
setopt INC_APPEND_HISTORY # adds history incrementally and share it across sessions
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS # don't record dupes in history
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt HIST_EXPIRE_DUPS_FIRST
# dont ask for confirmation in rm globs*
setopt RM_STAR_SILENT

bindkey "$terminfo[kcuu1]" history-substring-search-up # Up Arrow?
bindkey "$terminfo[kcud1]" history-substring-search-down # Down Arrow?
bindkey "$terminfo[cuu1]" history-substring-search-up
bindkey "$terminfo[cud1]" history-substring-search-down
bindkey '^[^[[D' backward-word # F4
bindkey '^[^[[C' forward-word # F3
bindkey '^[[5D' beginning-of-line
bindkey '^[[5C' end-of-line
bindkey '^[[3~' delete-char # Delete Key
bindkey '^?' backward-delete-char # Backspace
