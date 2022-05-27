#!/bin/sh

set -e

# Let's make this pretty
source ./echos.sh

# OS detection
function is_osx() {
  [[ "$OSTYPE" =~ ^darwin ]] || return 1
}
function is_ubuntu() {
  [[ "$(cat /etc/issue 2> /dev/null)" =~ Ubuntu ]] || return 1
}
function is_ubuntu_desktop() {
  dpkg -l ubuntu-desktop >/dev/null 2>&1 || return 1
}
function is_kali() {
  [[ "$(cat /etc/issue 2> /dev/null)" =~ Kali ]] || return 1
}

# if [[ "GITHUB_TOKEN" == "" ]]; then
#   error "Please set GITHUB_TOKEN before continuing"
#   exit 1
# fi

# if [[ "HOMEBREW_GITHUB_API_TOKEN" == "" ]] && is_osx; then
#   error "Mac user, please set HOMEBREW_GITHUB_API_TOKEN before continuing"
#   exit 1
# fi

export DOTFILES=~/.dotfiles

bot "DOTFILES are $DOTFILES"

if [[ "${DOTFILES}" == *"scripts"* ]]; then
  bot "Please run from $DOTFILES, not the scripts subdirectory"
  error "Now exiting with error"
  exit 1;
fi

## Link dotfiles

# force link
# -f for files
# -fF for directories

bot "Linking dotfile symlinks"

./links.sh

if [[ is_osx ]]; then
  ln -sfF ~/.dotfiles/cider ~/.cider
  ln -sfF ~/.dotfiles/karabiner ~/.config/karabiner
fi

if [[ ! "$(type -P gcc)" ]] && is_osx; then
  echo "Error: XCode or the Command Line Tools for XCode must be installed first."
  echo "Run xcode-select --install"
  exit 1
fi

if [[ ! -f `which brew` ]] && is_osx; then
  bot "Installing Homebrew"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  if [[ $? != 0 ]]; then
    error "ERROR: Unable to install Homebrew! Aborting now!"
    exit 1
  fi
else
  echo "Updating Homebrew"
  brew update
fi

if [[ ! -f `which cider` ]] && is_osx; then
  bot "Installing cider"
  pip install -U cider
fi

if [[ is_osx ]]; then
  echo "Restoring apps & tools with Cider"
  # https://github.com/msanders/cider
  cider restore
  echo "Cleaning up Homebrew installs"
  brew cleanup > /dev/null 2>&1
fi

# Ask for the administrator password upfront
bot "I need you to enter your sudo password so I can install some things:"
sudo -v

# Keep-alive: update existing sudo time stamp until the script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# /etc/hosts
read -r -p "Overwrite /etc/hosts with the ad-blocking hosts file from someonewhocares.org? (from ./configs/hosts file) [y|N] " response
if [[ $response =~ (yes|y|Y) ]]; then
    action "cp /etc/hosts /etc/hosts.backup"
    sudo cp /etc/hosts /etc/hosts.backup
    ok
    action "cp ./hosts /etc/hosts"
    sudo cp ./hosts /etc/hosts
    ok
    bot "Your /etc/hosts file has been updated. Last version is saved in /etc/hosts.backup"
fi

# set zsh as the user login shell
if [[ is_osx ]]; then
  # if [[ -f "/usr/local/bin/zsh" ]]; then
  #   bot "setting newer homebrew zsh (/usr/local/bin/zsh) as your shell (password required)"
  #   sudo dscl . -change /Users/$USER UserShell $SHELL /usr/local/bin/zsh > /dev/null 2>&1
  # else
    bot "setting older macos zsh (/bin/zsh) as your shell (password required)"
    sudo dscl . -change /Users/$USER UserShell $SHELL /bin/zsh > /dev/null 2>&1
  # fi
elif [[ is_ubuntu || is_kali ]]
  chsh -s `which zsh`
fi

# vim
bot "Installing vim plugins"

if [[ ! -d $HOME/.vim/bundle/Vundle.vim ]]; then
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi

vim +PluginInstall +qall > /dev/null 2>&1

bot "installing fonts"
./fonts/install.sh

bot "installing fzf"
./fzf/install.sh

bot "installing vscode"
./vscode/install.sh

if [[ is_osx ]]; then
  bot "installing iTerm settings"
  ./iterm2/install.sh
fi

warn "Don't forgot to run ./macos/macos.sh MANUALLY"

## TODO
#  Secure Install https://github.com/drduh/macOS-Security-and-Privacy-Guide
#  Cleanup after apt install
#  Install apt programs
