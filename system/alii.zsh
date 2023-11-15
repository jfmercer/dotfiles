alias reload="exec $SHELL -l"

# Easier navigation: .., ..., ...., ....., ~ and -
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~" # `cd` is probably faster to type though
alias -- -="cd -"

# Shortcuts
alias C="cd ~/Code"
alias c="code ."
alias dl="cd ~/Downloads"
alias dt="cd ~/Desktop"
alias erc="code ~/$DOTFILES"
alias h="history"
alias v="vim ."
alias ev="vim ~/.vimrc"
alias o="open"
alias oo="open ."
alias tmux="tmux -2"
alias diff="colordiff"

# I like to protect myself from myself...
alias mv="mv -i"
alias cp="cp -i"
# alias rm="rm -i"
alias ln="ln -i"

# Enable sudo to be sudo’ed
alias sudo 'sudo '

# Always enable colored `grep` output
# Note: `GREP_OPTIONS="--color=auto"` is deprecated, hence the alias usage.
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# IP addresses
alias myip="dig @resolver4.opendns.com myip.opendns.com +short"
alias myip4="dig @resolver4.opendns.com myip.opendns.com +short -4"
alias myip6="dig @resolver1.ipv6-sandbox.opendns.com AAAA myip.opendns.com +short -6"
alias localip="ipconfig getifaddr en0"
alias ips="ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"

# Enhanced WHOIS lookups
# alias whois="whois -h whois-servers.net"

# View HTTP traffic
alias sniff="sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump="sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""

# Canonical hex dump; some systems have this symlinked
alias hd="hexdump -C"

alias unixtime="date +%s"

# File size
alias fs="stat -c \"%s bytes\""

# chezmoi
alias cm=chezmoi

# arsenal
alias a=arsenal

# colorize less
alias less="less -R"

# rustscan via podman
alias rustscan='podman run -it --rm --name rustscan rustscan/rustscan:latest'
