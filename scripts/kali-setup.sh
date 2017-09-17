#!/bin/bash

apt-get update && apt-get upgrade -y
# apt-get install kali-linux-all -y
apt-get install terminator -y
# Set terminator as default app
# This can be a pain sometimes
# Cf. https://stackoverflow.com/q/16808231/754842
gsettings set org.gnome.desktop.default-applications.terminal exec /usr/bin/terminator
gsettings set org.gnome.desktop.default-applications.terminal exec-arg “-x”
# sudo update-alternatives --config x-terminal-emulator
# sudo mv /usr/bin/gnome-terminal /usr/bin/gnome-terminal.bak
# sudo ln -s /usr/bin/terminator /usr/bin/gnome-terminal
apt-get install silversearcher-ag

# Install VSCode
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt-get update
sudo apt-get install code
