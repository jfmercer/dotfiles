#!/bin/zsh
# The max execution time of a process before its run time is shown when it exits.
PURE_CMD_MAX_EXEC_TIME=1
# Prevents Pure from checking whether the current Git remote has been updated.
PURE_GIT_PULL=0

ZPLUGINDIR=$HOME/.dotfiles/plugins/bundle

fpath+=$ZPLUGINDIR/pure
autoload -U promptinit; promptinit
prompt pure
