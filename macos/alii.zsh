# macOS-only aliases. dot_zshrc sources every */*.zsh unconditionally, so this
# needs its own guard -- previously all of these were defined on Linux too,
# where none of them work.
[[ $OSTYPE == darwin* ]] || return 0

# OS X has no `md5sum`, so use `md5` as a fallback
alias mac5sum="md5"

# Trim new lines and copy to clipboard
alias cc="tr -d '\n' | pbcopy"

# Recursively delete `.DS_Store` files
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"

# Flush Directory Service cache
alias flush="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; echo 'flushed'"

# Empty the Trash on all mounted volumes and the main HDD
# Also, clear Apple’s System Logs to improve shell startup speed
alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl"

# Show/hide hidden files in Finder
# NB: `; and` is fish syntax -- in zsh it ran `and killall Finder`, i.e.
# "command not found", so the Finder never actually restarted.
alias show="defaults write com.apple.Finder AppleShowAllFiles -bool true && killall Finder"
alias hide="defaults write com.apple.Finder AppleShowAllFiles -bool false && killall Finder"

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

# Disable Spotlight
alias spotoff="sudo mdutil -a -i off"
# Enable Spotlight
alias spoton="sudo mdutil -a -i on"

# Clear the Download Log
alias cleardl="sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent'"

# Open file in Marked 2
alias oim="open -a /Applications/Marked\ 2.app/"
