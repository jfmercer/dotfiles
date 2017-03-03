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
echo "Grabbing Dupes"
brew tap homebrew/dupes
brew tap homebrew/completions
brew tap homebrew/versions

# Array list of Homebrew formulae to install
# Move vim outside. Prob. zsh-* as well
myBrew=(autoconf
        bash
        bash-completion
        colordiff
        coreutils
        git
        hub
        ssh-copy-id
        tig
        tree
        "vim --override-system-vi --with-python3"
        wget
        zsh
        zsh-completion
        zsh-syntax-highlighting
        )

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

# Clean up the Cellar
brew cleanup
brew prune

echo "All done!"
