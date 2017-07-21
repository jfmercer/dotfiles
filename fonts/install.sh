if [ "$(uname -s)" == "Darwin" ]; then
  echo "Run `cider install` to install macOS fonts"
  # if which brew >/dev/null 2>&1; then
  #   brew tap caskroom/fonts
  #   typeset -a custom_fonts
  #   custom_fonts=(
  #     font-anonymous-pro
  #     font-anonymouspro-nerd-font
  #     font-anonymouspro-nerd-font-mono
  #     font-awesome-terminal-fonts
  #     font-devicons
  #     font-fontawesome
  #     font-icomoon
  #     font-inconsolata
  #     font-inconsolata-dz
  #     font-inconsolata-for-powerline
  #     font-inconsolata-nerd-font
  #     font-inconsolata-nerd-font-mono
  #     font-meslo-for-powerline
  #     font-meslo-lg
  #     font-meslo-nerd-font
  #     font-meslo-nerd-font-mono
  #     font-octicons
  #     font-source-code-pro
  #     font-sourcecodepro-nerd-font
  #     font-sourcecodepro-nerd-font-mono
  #     font-source-code-pro-for-powerline
  #   )

  #   for font in ${custom_fonts[@]}
  #   do
  #     if [[ `brew cask ls | grep $font` != "" ]]; then
  #       echo $font "is already installed"
  #     else
  #       echo "now installing " $font
  #       brew cask install $font >/dev/null 2>&1
  #     fi
  #   done

  #   unset custom_fonts

  #   echo "macOS font install complete"
  #   exit 0
  # else
  #   echo "Error: Homebrew not installed"
  #   echo "Please install Homebrew"
  #   exit 1
  # fi
else
  echo "Please enter password to install fonts"
  sudo apt-get install -y fonts-powerline font-inconsolata ttf-anonymous-pro
  # TODO: Add awesome-terminal-fonts with these directions
  # https://github.com/gabrielelana/awesome-terminal-fonts#how-to-install-linux
fi
