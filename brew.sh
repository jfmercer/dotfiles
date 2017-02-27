#!/bin/bash

# Make sure we're on a Mac
if [[ "$OSTYPE" =~ ^darwin ]]; then
    echo "Since this is a Mac, let's roll Homebrew."
else
    echo "This ain't a Mac! Exiting now."
    exit 0
fi

# Install Homebrew
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Update Homebrew formulae & upgrade existing packages
echo "Updating Homebrew and upgrading existing packages"
brew update && brew upgrade

# Grab duplicate formulae
echo "Grabbing Dupes and PHP"
brew tap homebrew/dupes
brew tap homebrew/php
brew tap homebrew/completions
brew tap homebrew/versions

# Array list of Homebrew formulae to install
# Move vim outside. Prob. zsh-* as well
myBrew=(autoconf bash bash-completion brew-php-switcher colordiff coreutils cowsay homebrew/versions/elasticsearch13 fortune freetds git hub mcrypt mysql node pkg-config python python3 ssh-copy-id subversion tig tree unixodbc "vim --override-system-vi --with-python3" wget zsh zsh-completion zsh-syntax-highlighting )

# Array list of dupes to install
myDupes=( awk bzip2 grep gzip less make tidy unzip whois )

# Run installs
echo "Installing packages"
for i in ${myBrew[*]}
do
    brew install $i
done

echo "Installing duplicate packages"
for i in ${myDupes[*]}
do
    brew install $i
done

# Install composer independently of Homebrew using OS X's native PHP 5.5 (/usr/bin/php)
mkdir -p ~/.composer/vendor/bin
curl -sS https://getcomposer.org/installer | php -- --install-dir=~/.composer/vendor/bin --filename=composer

# Install all PHPs
brew install php53 --with-mssql && brew unlink php53 && brew install php54 --with-mssql --with-phpdebug && brew unlink php54 && brew install php55 --with-mssql --with-phpdebug && brew unlink php55 && brew install php56 --with-mssql --with-phpdebug && brew unlink php56 && brew link php53 && brew install php53-mcrypt php53-oauth php53-pdo-dblib php53-xdebug && brew unlink php53 && brew link php54 && brew install php54-mcrypt php54-oauth php54-pdo-dblib php54-xdebug && brew unlink php54 && brew link php55 && brew install php55-mcrypt php55-oauth php55-xdebug && brew unlink php55 && brew link php56 && brew install php56-mcrypt php56-oauth php56-xdebug

# Clean up the Cellar
brew cleanup

echo "All done!"
