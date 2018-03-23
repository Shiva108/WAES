#!/usr/bin/env bash
# 2018 by Shiva @ CPH:SEC & Cyberium
# Creds to Common Exploits, Supra, Offensive & lisandrogallo

# Script begins
#===============================================================================


VERSION="0.0.1a"
# Where to find vulners.nse
VULNERSDIR="/home/e"

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
echo "       -u url to test"
echo ""
}

# Check input parameters
if [ $# -eq 0 ]
  then
    usage
    echo "No arguments supplied"
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
locate vulners>/dev/null
if [ $? -eq 0 ]
        then
                echo ""
else
                echo ""
       		echo -e "\e[01;31m[!]\e[00m Unable to find the required nmap script vulners.nse, install and try again"
        exit 1
fi

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
# echo -e "[+] Looking up "$2" with whatweb"
# whatweb -a3 $2 | tee $2_whatweb.txt

# nmap
# echo -e "[+] nmap with http-enum on $2"
# nmap -sSV -Pn -O --script http-enum $2 -oA $2_nmap_http-enum
# echo -e "[+] nmap with vulners on $2"
# nmap -sSV -Pn -A --script $VULNERSDIR/vulners.nse $2 -oA $2_nmap_vulners

# nikto
echo -e "[+] nikto with on $2"
nikto -h $2 -C all | tee $2_nikto.txt

# uniscan

