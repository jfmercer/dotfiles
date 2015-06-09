# Use `hub` as our git wrapper:
#   http://defunkt.github.com/hub/
hub_path=$(which hub)
if (( $+commands[hub] ))
then
  alias git=$hub_path
fi

alias ga='git add'
alias gaa='git add -A' # Identical to "git add .; git add -u" cf: https://stackexchange.com/users/login#log-in
alias gl="git log --graph --pretty=format:'%Cred%h%Creset %an: %s - %Creset %C(yellow)%d%Creset %Cgreen(%cr)%Creset' --abbrev-commit --date=relative"
alias gp='git push origin HEAD'
alias gd='git diff'
alias gc='git commit'
alias gca='git commit -a'
alias gcm='git commit -m'
alias gco='git checkout'
alias gcb='git copy-branch-name'
alias gb='git branch'
alias gpf='git push -f'
alias gs='git status -sb' # upgrade your git if -sb breaks for you. it's fun.
alias gst='git status'
