#!/bin/sh
if test "$(which code)"; then
  if [ "$(uname -s)" = "Darwin" ]; then
    VSCODE_HOME="$HOME/Library/Application\ Support/Code"
  else
    VSCODE_HOME="$HOME/.config/Code"
  fi

  ln -sf "$DOTFILES/vscode/settings.json" "$VSCODE_HOME/User/settings.json"
  ln -sf "$DOTFILES/vscode/keybindings.json" "$VSCODE_HOME/User/keybindings.json"

  # from `code --list-extensions`
  modules="
    EditorConfig.EditorConfig
    PeterJausovec.vscode-docker
    Valiantsin.operatormonodarktheme
    Zignd.html-css-class-completion
    christian-kohler.npm-intellisense
    christian-kohler.path-intellisense
    dbaeumer.vscode-eslint
    dracula-theme.theme-dracula
    eg2.tslint
    eg2.vscode-npm-script
    flowtype.flow-for-vscode
    johnpapa.Angular2
    lkytal.FlatUI
    mkaufman.HTMLHint
    msjsdiag.debugger-for-chrome
    shinnn.stylelint
    vscodevim.vim
    zhuangtongfa.Material-theme
"
  for module in $modules; do
    code --install-extension "$module" || true
  done
fi
