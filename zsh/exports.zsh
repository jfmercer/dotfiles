# VISUAL/EDITOR and the XDG base dirs live in dot_zshenv, so non-interactive
# shells, cron jobs and git hooks get them too.
export SHELL=${commands[zsh]}
export ANSIBLE_NOCOWS=1
# TERM is deliberately NOT set unconditionally. The terminal knows what it is:
# Ghostty sets xterm-ghostty, tmux sets tmux-256color (dot_tmux.conf), herdr
# sets its own. Blanket-forcing xterm-256color threw all of that away -- it cost
# undercurl and the kitty keyboard protocol under Ghostty, replaced tmux's own
# terminfo, and actively lied on the Linux virtual console (TERM=linux), which
# has neither 256 colors nor xterm's key sequences.
#
# The one case where overriding is right is a TERM this machine has no terminfo
# entry for at all -- e.g. ssh-ing from Ghostty into a box without
# xterm-ghostty, or into a Debian box lacking ncurses-term. Detect that with the
# zsh/terminfo module rather than forking infocmp. (zsh/config.zsh already
# relies on $terminfo, so the module is loaded anyway.)
#
# Test on the capability COUNT, not on a specific capability: every real entry
# has 50+ capabilities and a missing one has exactly 0. Testing terminfo[colors]
# would wrongly clobber monochrome-but-real terminals (vt100, vt220 -- serial
# consoles and network gear), and testing terminfo[cup] would clobber `dumb`,
# which editors and CI set on purpose.
# Only override when the module actually loaded AND reported no capabilities.
# If zsh/terminfo is unavailable we cannot tell, so leave TERM alone rather
# than guess.
if zmodload zsh/terminfo 2>/dev/null && (( ${#terminfo} == 0 )); then
  export TERM=xterm-256color
fi
