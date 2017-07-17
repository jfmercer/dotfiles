alias reload="source $HOME/.zshrc"

# Shortcuts
alias D="cd ~/Dropbox"
alias C="cd ~/Code"
alias c="code ."
alias dl="cd ~/Downloads"
alias dt="cd ~/Desktop"
alias erc="code ~/.fishfiles"
alias h="history"
alias v="vim ."
alias ev="vim ~/.vimrc"
alias o="open"
alias oo="open ."
alias mad="cd ~/.mad"
alias tmux="TERM screen-256color-bce tmux"
alias diff="colordiff"

# I like to protect myself from myself...
alias mv="mv -i"
alias cp="cp -i"
# alias rm="rm -i"
alias ln="ln -i"

# Fix Homebrew permission issues
# alias fixbrew 'sudo chown -R (eval whoami):wheel (eval brew --prefix)'

# Enable sudo to be sudo’ed
alias sudo 'sudo '

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en1"
alias ips="ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"

# Enhanced WHOIS lookups
alias whois="whois -h whois-servers.net"

# Flush Directory Service cache
alias flush="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; echo 'flushed'"

# View HTTP traffic
alias sniff="sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump="sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""

# Canonical hex dump; some systems have this symlinked
alias hd="hexdump -C"

# OS X has no `md5sum`, so use `md5` as a fallback
alias md5sum="md5"

# Trim new lines and copy to clipboard
alias cc="tr -d '\n' | pbcopy"

# Recursively delete `.DS_Store` files
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"

alias unixtime="date +%s"

# File size
alias fs="stat -c \"%s bytes\""

# Empty the Trash on all mounted volumes and the main HDD
# Also, clear Apple’s System Logs to improve shell startup speed
alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl"

# Show/hide hidden files in Finder
alias show="defaults write com.apple.Finder AppleShowAllFiles -bool true ; and killall Finder"
alias hide="defaults write com.apple.Finder AppleShowAllFiles -bool false ; and killall Finder"

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false ; and killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true ; and killall Finder"

# Disable Spotlight
alias spotoff="sudo mdutil -a -i off"
# Enable Spotlight
alias spoton="sudo mdutil -a -i on"

# Clear the Download Log
alias cleardl="sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent'"

# Open file in Marked 2
alias oim="open -a /Applications/Marked\ 2.app/"
