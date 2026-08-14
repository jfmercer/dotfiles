# Always use eza, the better ls
#
# --icons is `auto`, not `always`, deliberately breaking symmetry with
# --color=always above. Color is out-of-band -- escape codes a pipe consumer can
# strip -- but an icon is a real character prepended to the name, so
# --icons=always makes `ls | xargs` and `ls | grep` operate on filenames that no
# longer match anything on disk. `auto` means a TTY only, which is every case
# where a human is looking at it.
#
# The glyphs come from the Nerd Font set, so they need a terminal whose font
# carries them -- dot_config/ghostty/config.tmpl. They will render as boxes in
# Terminal.app (its terminal/*.terminal profiles do not set a Nerd Font) and
# over ssh to a host viewed through any non-Nerd font.
alias ls="command eza --color=always --icons=auto"
# List only directories
alias lsd="ls -lFD"

# List all files colorized in long format
alias l="ls -lgF"
# List all files colorized in long format, including dot files
alias ll="ls -lagF"

