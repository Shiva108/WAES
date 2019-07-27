#!/usr/bin/env bash

if [[ `id -u` -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

echo "Installing...."
echo " "
sudo apt update
sudo apt install whatweb
sudo apt install wafw00f
sudo apt install uniscan
sudo apt install gobuster
sudo apt install nikto
sudo mkdir report
sudo git clone https://github.com/danielmiessler/SecLists.git
sudo git clone https://github.com/scipag/vulscan
echo " "
echo "Installation is done"
