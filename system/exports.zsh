# Directories to Export into $PATH
# export PATH=/usr/local/bin:/usr/local/sbin:$PATH
# Make vim the default editor
export EDITOR="vim"
# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"
# Highlight section titles in manual pages
export LESS_TERMCAP_md="$ORANGE"
# set $SHELL
export SHELL="/usr/local/bin/zsh"
export HISTFILE=~/.zsh_history
# Larger zsh history (allow 32³ entries; default is 500)
export HISTSIZE=32768
export HISTFILESIZE=$HISTSIZE
export HISTCONTROL=ignoredups
# Make some commands not show up in history
export HISTIGNORE="ls:ls *:cd:cd -:pwd;exit:date:* --help"

# export JAVA6_HOME=`/usr/libexec/java_home -v 1.6`
export JAVA7_HOME=`/usr/libexec/java_home -v 1.7`
# export JAVA8_HOME=`/usr/libexec/java_home -v 1.8`
export JAVA_HOME=$JAVA7_HOME
# export MAVEN_HOME=/usr/local/Cellar/maven/

# Disables automatic cowsay on Ansible
export ANSIBLE_NOCOWS=1
