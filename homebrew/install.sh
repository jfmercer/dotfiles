#!/bin/sh
#
# Homebrew
#
# This installs some of the common dependencies needed (or at least desired)
# using Homebrew.

# Check for Homebrew
if test ! $(which brew)
then
  echo "  Installing Homebrew for you."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo "Updating existing Homebrew packages"
brew update

myTaps=( homebrew/completions homebrew/dupes homebrew/php homebrew/services homebrew/versions )

myBrew=(ansible autoconf bash bash-completion brew-php-switcher colordiff coreutils cowsay findutils fortune git git-crypt grc hub mcrypt moreutils mysql node pkg-config python python3 ssh-copy-id subversion tig tree "vim --override-system-vi --with-python3" wget zsh zsh-completions zsh-syntax-highlighting )

myDupes=( awk bzip2 grep gzip less make unzip whois )

# Grab extra formulae
echo "Tapping . . . "
for i in ${myTaps[*]}
do
    brew tap $i 2>/dev/null
done

# Run installs
echo "Installing Homebrew packages"
for i in ${myBrew[*]}
do
    brew install $i 2>/dev/null
done

echo "Installing Homebrew duplicate packages"
for i in ${myDupes[*]}
do
    brew install $i 2>/dev/null
done

# Install composer independently of Homebrew using OS X's native PHP 5.5 (/usr/bin/php)
if ! [ -f $HOME/.composer/vendor/bin/composer ]
then
  echo "Installing composer"
  mkdir -p $HOME/.composer/vendor/bin
  curl -sS https://getcomposer.org/installer | /usr/bin/php -- --install-dir=$HOME/.composer/vendor/bin --filename=composer
fi

# Install all PHPs
#brew install php53 && brew unlink php53 && brew install php54 --with-phpdebug && brew unlink php54 && brew install php55 --with-phpdebug && brew unlink php55 && brew install php56 --with-phpdebug && brew unlink php56 && brew link php53 && brew install php53-mcrypt php53-oauth php53-xdebug && brew unlink php53 && brew link php54 && brew install php54-mcrypt php54-oauth php54-xdebug && brew unlink php54 && brew link php55 && brew install php55-mcrypt php55-oauth php55-xdebug && brew unlink php55 && brew link php56 && brew install php56-mcrypt php56-oauth php56-xdebug

# Clean up the Cellar
echo "Cleaning up . . . "
brew prune
brew cleanup

echo "Homebrew install complete!"

exit 0
