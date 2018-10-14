#!/usr/bin/env bash

# Nothing to see here.

#!/usr/bin/env bash
# 2018 by Shiva @ CPH:SEC

# WAES requires vulners.nse     : https://github.com/vulnersCom/nmap-vulners
# WAES requires supergobuster   : https://gist.github.com/lokori/17a604cad15e30ddae932050bbcc42f9
# WAEs requires SecLists        : https://github.com/danielmiessler/SecLists


# Script begins
#===============================================================================


VERSION="0.0.3b"
# Where to find vulners.nse :
VULNERSDIR="nmap-vulners"
SECLISTDIR="SecLists"
REPORTDIR="report" # report directory
TOOLS=( "nmap" "nikto" "uniscan" "gobuster" "dirb" "whatweb" )

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

# Checks for input parameters
: ${1?"No arguments supplied - run waes -h for help or cat README.md"}


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

# Check for nmap
which nmap>/dev/null
if [ $? -eq 0 ]
        then
                echo ""
else
                echo ""
       		echo -e "\e[01;31m[!]\e[00m Unable to find the required nmap program, install and try again"
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
echo -e "Target: $2 "

echo -e "[+] OSIRA on:" $2
OSIRA/osira.sh -u $2 | tee ${REPORTDIR}/$2_osira.txt
mv $2.txt ${REPORTDIR}/$2_osira.txt