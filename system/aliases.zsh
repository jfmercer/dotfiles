# Easier navigation: .., ..., ...., ....., ~ and -
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~" # `cd` is probably faster to type though
alias -- -="cd -"

# Shortcuts
alias d="cd ~/Dropbox"
alias C="cd ~/Code"
alias dl="cd ~/Downloads"
alias dt="cd ~/Desktop"
alias g="git"
alias h="history"
alias v="vim"
alias s="subl ."
alias o="open"
alias oo="open ."
alias mad="cd ~/.mad"
alias tmux="TERM=screen-256color-bce tmux"
alias diff="colordiff"

# I like to protect myself from myself...
alias mv="mv -i"
alias cp="cp -i"
# alias rm="rm -i"
alias ln="ln -i"

# Let's improve ls
# List all files colorized in long format
alias l="ls -Gl"
# List all files colorized in long format, including dot files
alias la="ls -Gla"
# List only directories
alias lsd='ls -l | grep "^d"'
# Always use color output for `ls`
#if [[ "$OSTYPE" != ^darwin ]]; then
#	alias ls="command ls -G"
#else
#	alias ls="command ls --color"
#	export LS_COLORS='no=00:fi=00:di=01;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:'
#fi

# Fix Homebrew permission issues
alias fixbrew='sudo chown -R $(whoami):admin $(brew --prefix)'

# Enable aliases to be sudo’ed
alias sudo='sudo '

# Get OS X Software Updates, update Homebrew itself, and upgrade installed Homebrew packages
alias update='sudo softwareupdate -i -a; brew update; brew upgrade'

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en1"
alias ips="ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"

# Enhanced WHOIS lookups
alias whois="whois -h whois-servers.net"

# Flush Directory Service cache
alias flush="sudo discoveryutil mdnsflushcache; sudo discoveryutil udnsflushcaches; echo 'flushed'"

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

# File size
alias fs="stat -c \"%s bytes\""

# Empty the Trash on all mounted volumes and the main HDD
# Also, clear Apple’s System Logs to improve shell startup speed
alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl"

# Show/hide hidden files in Finder
alias show="defaults write com.apple.Finder AppleShowAllFiles -bool true && killall Finder"
alias hide="defaults write com.apple.Finder AppleShowAllFiles -bool false && killall Finder"

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

# Disable Spotlight
alias spotoff="sudo mdutil -a -i off"
# Enable Spotlight
alias spoton="sudo mdutil -a -i on"

#Generate Random MAC address
alias rmac="openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//'"
# Spoof MAC address
alias spoof="openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | tr '[:lower:]' '[:upper:]' | xargs sudo ifconfig en0 ether"

# Lock the screen (when going AFK)
alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"

# Reload the shell (i.e. invoke as a login shell)
alias reload="exec $SHELL -l"

# Clear the Download Log
alias cleardl="sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent'"

# Firefox Profile Manager
alias ffprofile="/Applications/Firefox.app/Contents/MacOS/firefox-bin -p"

# Homestead
alias hs='homestead'

# Apache
alias macvhost="sudo vim /etc/apache2/extra/httpd-vhosts.conf"
alias bps="brew-php-switcher"
alias arestart="sudo apachectl restart"
alias alogs='cd /private/var/log/apache2'

# MySQL
alias mrestart="sudo mysql.server restart"
alias killmysql="launchctl unload -w ~/Library/LaunchAgents/homebrew.mxcl.mysql.plist"

# MySQL and Apache
alias start="mysql.server start && sudo apachectl start"
alias stop="mysql.server stop && sudo apachectl stop"

# PHP
alias e53="vim /usr/local/etc/php/5.3/php.ini"
alias e54="vim /usr/local/etc/php/5.4/php.ini"
alias e55="vim /usr/local/etc/php/5.5/php.ini"
alias e56="vim /usr/local/etc/php/5.6/php.ini"

# ElasticSearch
alias startes="elasticsearch --config=/usr/local/opt/elasticsearch13/config/elasticsearch.yml"

# git
# Delete Merged Branches on localhost
alias dmb="git branch --merged | grep -v "\*" | xargs -n 1 git branch -d"
# Github
alias git=hub

