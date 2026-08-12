# initialize homebrew from a cached copy of `brew shellenv`
# (see cached-eval in dot_zshrc)
#
# This MUST stay a path.zsh. `brew shellenv` is what puts /opt/homebrew/bin on
# PATH, and /opt/homebrew/bin is in neither /etc/paths nor /etc/paths.d -- so
# until this runs, no Homebrew-installed binary resolves. As homebrew.zsh it ran
# in dot_zshrc's general `*/*.zsh` pass, which is alphabetical, so every topic
# dir sorting before homebrew/ (asdf, atuin, fzf, git, gpg) looked for its tool
# on a PATH that did not have it yet. cached-eval's `[[ -x $bin ]]` then returned
# 0 silently, and atuin's Ctrl-R plus fzf's Ctrl-T/Alt-C simply never got bound.
#
# That only bit shells whose parent had no Homebrew on PATH -- which is exactly
# the herdr panes, since Ghostty is a GUI launch (see bin/ghostty-session) and
# the herdr server hands its own environment to every pane it spawns.
if [[ -x /opt/homebrew/bin/brew ]]; then
  cached-eval brew-shellenv /opt/homebrew/bin/brew shellenv
fi
