#!/usr/bin/env bash
# 2018 by Shiva @ CPH:SEC

# WAES requires vulners.nse     : https://github.com/vulnersCom/nmap-vulners
# WAES requires supergobuster   : https://gist.github.com/lokori/17a604cad15e30ddae932050bbcc42f9
# WAEs requires SecLists        : https://github.com/danielmiessler/SecLists


# Script begins
#===============================================================================


VERSION="0.0.2b"
# Where to find vulners.nse :
VULNERSDIR="nmap-vulners"
SECLISTDIR="SecLists"

echo ""
echo -e "\e[00;32m#############################################################\e[00m"
echo ""
echo -e "	Web Auto Enum & Scanner $VERSION "
echo ""
echo -e "	Auto enums website(s) and dumps files as result"
echo ""
echo -e "\e[00;32m#############################################################\e[00m"
echo ""

usage ()
{
echo "Usage: ${0##*/} -u {url}"
echo "       ${0##*/} -h"
echo ""
echo "       -h shows this help"
echo "       -u url to test without http or https e.g. testsite.com"
echo ""
}

: ${1?"No arguments supplied - run waes -h for help or cat README.md"}


# Deprecated! - Check input parameters
#if [ $ -eq 0 ]
#  then
#    usage
#    echo "No arguments supplied"
#    exit 1
#fi

if [ $1 == "-h" ]
  then
    usage
    exit 1
fi

if [[ "$1" != "-u" && "$1" != "-h" ]]; then
   usage
   echo "Invalid parameter: $1"
   exit 1
fi

# Bug to fix in later version
# if [ -u "$1" == ""]; then
#     usage
#     echo "No argument supplied"
# fi

#Check for nmap
which nmap>/dev/null
if [ $? -eq 0 ]
        then
                echo ""
else
                echo ""
       		echo -e "\e[01;31m[!]\e[00m Unable to find the required nmap program, install and try again"
        exit 1
fi

#Check for vulners.nse
#locate vulners>/dev/null
#if [ $? -eq 0 ]
#        then
#                echo ""
#else
#                echo ""
#       		echo -e "\e[01;31m[!]\e[00m Unable to find the required nmap script vulners.nse, install and try again"
#        exit 1
#fi

# Removing HTTP and HTTPS
# $2=echo $2 | rev | cut -d '/' -f 1 | rev

#Check for nikto
which nikto>/dev/null
if [ $? -eq 0 ]
        then
                echo ""
else
                echo ""
       		echo -e "\e[01;31m[!]\e[00m Unable to find the required nikto program, install and try again"
        exit 1
fi

#Check for uniscan
which uniscan>/dev/null
if [ $? -eq 0 ]
        then
                echo ""
else
                echo ""
       		echo -e "\e[01;31m[!]\e[00m Unable to find the required uniscan program, install and try again"
        exit 1
fi

# Check if root
if [[ $EUID -ne 0 ]]; then
        echo ""
        echo -e "\e[01;31m[!]\e[00m This program must be run as root. Run again with 'sudo'"
        echo ""
        exit 1
fi

#
echo -e "Target: is $2 "

# Whatweb
echo -e "[+] Looking p "$2" with whatweb"
whatweb -a3 $2 | tee report/$2_whatweb.txt

# nmap
#echo -e "[+] nmap with standard scripts (-sC) on $2"
#nmap -sSCV -Pn -vv $2 -oA report/$2_nmap_sSCV
#echo -e "[+] nmap with http-enum on $2"
#nmap -sSV -Pn -O -vv --script http-enum $2 -oA report/$2_nmap_http-enum
#echo -e "[+] nmap with vulners on $2"
#nmap -sSV -Pn -A -vv --script vulners.nse $2 -oA $2_nmap_vulners

# nikto
echo -e "[+] nikto on $2"
nikto -h $2 -C all -ask no -evasion A | tee report/$2_nikto.txt

## uniscan
#echo -e "[+] uniscan on $2"
#uniscan -u $2 -qweds | tee report/$2_uniscan.txt
