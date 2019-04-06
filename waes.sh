#!/usr/bin/env bash
# 2018-2019 by Shiva @ CPH:SEC

# Todo: Cleanup
# WAES requires supergobuster   : https://gist.github.com/lokori/17a604cad15e30ddae932050bbcc42f9
# WAEs requires SecLists        : https://github.com/danielmiessler/SecLists


# Script begins
#===============================================================================


# vars
VERSION="0.0.31d"
VULNERSDIR="nmap-vulners" # Where to find vulners.nse
REPORTDIR="report" # /report directory
TOOLS=( "nmap" "nikto" "uniscan" "gobuster" "dirb" "whatweb" )
SECLISTDIR="SecLists" # Todo: Use var and pass to next script

#banner / help message
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

if [[ `id -u` -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

# Checks for input parameters
: ${1?"No arguments supplied - run waes -h for help or cat README.md"}


if [[ $1 == "-h" ]]
  then
    usage
    exit 1
fi

if [[ "$1" != "-u" && "$1" != "-h" ]]; then
   usage
   echo "Invalid parameter: $1"
   exit 1
fi

# Todo: Use 1 loop for all tools
# Check for nmap
which nmap>/dev/null
if [[ $? -eq 0 ]]
        then
                echo ""
else
                echo ""
       		echo -e "\e[01;31m[!]\e[00m Unable to find the required nmap program, install and try again"
        exit 1
fi

#Check for nikto
which nikto>/dev/null
if [[ $? -eq 0 ]]
        then
                echo ""
else
                echo ""
       		echo -e "\e[01;31m[!]\e[00m Unable to find the required nikto program, install and try again"
        exit 1
fi

#Check for uniscan
which uniscan>/dev/null
if [[ $? -eq 0 ]]
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

# Whatweb
# echo -e "\e[00;32m [+] Looking up "$2" with whatweb" "\e[00m"
# whatweb -a3 $2 | tee ${REPORTDIR}/$2_whatweb.txt

# OSIRA
# echo -e "\e[00;32m [+] OSIRA against:" $2 "\e[00m"
# OSIRA/osira.sh -u $2 | tee ${REPORTDIR}/$2_osira.txt
# mv $2.txt ${REPORTDIR}/$2_osira.txt

# nmap
echo -e "\e[00;32m [+] nmap with standard scripts (-sC) on $2" "\e[00m"
nmap -sSCV -Pn -T4 $2 -oA ${REPORTDIR}/$2_nmap_sSCV
echo -e "\e[00;32m [+] nmap with http-enum against $2" "\e[00m"
# Todo: Cleanup?
nmap -sSV -Pn -T4 --script http-enum $2 -oA ${REPORTDIR}/$2_nmap_http-enum
# echo -e "\e[00;32m [+] nmap with various HTTP scripts against $2" "\e[00m"
# nmap -sSV -Pn -T4 --script "http-*" $2 -oA ${REPORTDIR}/$2_nmap_http-va
# Todo: Change from vulners to new script
# echo -e "\e[00;32m [+] nmap with vulners on $2" "\e[00m"
# echo ${VULNERSDIR}"/vulners.nse"
#nmap -sV -Pn -O -T4 --script ${VULNERSDIR}/vulners.nse $2 --script-args mincvss=5-0 -oA ${REPORTDIR}/$2_nmap_vulners

# nikto
echo -e "\e[00;32m [+] nikto on $2" "\e[00m"
nikto -h $2 -C all -ask no -evasion A | tee $REPORTDIR/$2_nikto.txt

# uniscan
echo -e "\e[00;32m [+] uniscan of $2" "\e[00m"
uniscan -u $2 -qweds | tee $REPORTDIR/$2_uniscan.txt

# Supergobuster: gobuster + dirb
echo -e "\e[00;32m [+] super go busting $2" "\e[00m"
./supergobuster.sh $2 | tee $REPORTDIR/$2_supergobust.txt

echo -e "\e[00;32m [+] WAES is done. Find results in:" ${REPORTDIR} "\e[00m"

# Todo: Add FD tools: https://github.com/chrispetrou/FDsploit
# Todo: Add from rapidscan