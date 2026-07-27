# fzf's shell integration: Ctrl-T (files), Alt-C (cd), Ctrl-R (history).
# `fzf --zsh` (fzf >= 0.48) replaces the old $(brew --prefix)/opt/fzf/install
# script, which only ever wrote an ~/.fzf.zsh that nothing sourced -- so none
# of the FZF_*_COMMAND settings in exports.zsh were reachable.
# cached-eval (dot_zshrc) is a no-op when fzf isn't installed.
cached-eval fzf-init fzf --zsh

# atuin owns Ctrl-R (see atuin/atuin.zsh, loaded after this file), so fzf's
# history widget is intentionally shadowed. Ctrl-T and Alt-C are fzf's.
