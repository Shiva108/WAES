#!/usr/bin/env bash
# 2018-2019 by Shiva @ CPH:SEC

# Script begins
#===============================================================================

# set -x # Starts debugging

# vars
VERSION="0.0.31 alpha"
VULNERSDIR="vulscan" # Where to find vulscan
REPORTDIR="report" # /report directory
TOOLS=( "nmap" "nikto" "uniscan" "gobuster" "dirb" "whatweb" )
# Todo: Implement HTTPNSE list
HTTPNSE=( "http-date,http-title,http-server-header,http-headers,http-enum,http-devframework,http-dombased-xss,http-stored-xss,http-xssed,http-cookie-flags,http-errors,http-grep,http-traceroute" )
SECLISTDIR="SecLists" # Todo: Use var and pass to next script
PORT=( 80 ) # Todo: Implement PORT var
count=-1 # For tools loop

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

if [[ `id -u` -ne 0 ]] ; then echo -e "\e[01;31m[!]\e[00m This program must be run as root. Run again with 'sudo'" ; exit 1 ; fi

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

while [[ "x${TOOLS[count]}" != "x" ]]
do
   count=$(( $count + 1 ))
   if ! hash ${TOOLS[count]} /dev/null 2>&1
    then
        echo -e "\e[01;31m[!]\e[00m ${TOOLS[count]} was not found in PATH"
        echo "Run sudo ./install.sh to install tools"
    fi
done


echo -e "Target: $2 "

# Whatweb
#echo -e "\e[00;32m [+] Looking up "$2" with whatweb - only works for online targets" "\e[00m"
#whatweb -a3 $2 | tee ${REPORTDIR}/$2_whatweb.txt

## OSIRA - For subdomain enum
#echo -e "\e[00;32m [+] OSIRA against:" $2 "\e[00m"
#OSIRA/osira.sh -u $2 | tee ${REPORTDIR}/$2_osira.txt
#mv $2.txt ${REPORTDIR}/$2_osira.txt

# nmap
echo -e "\e[00;32m [+] nmap with various HTTP scripts against $2" "\e[00m"
nmap -sSV -Pn -T4 -v -p 80 --script $HTTPNSE $2 -oA ${REPORTDIR}/$2_nmap_http-va
# Todo: Change from vulners to new script
echo -e "\e[00;32m [+] nmap with vulscan on $2 with min CVSS 5.0" "\e[00m"
echo ${VULNERSDIR}
nmap -sSV -Pn -O -T4 --version-all -p 80 --script ${VULNERSDIR}/vulscan.nse $2 --script-args mincvss=5-0 -oA ${REPORTDIR}/$2_nmap_vulners

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

# Todo: Add from rapidscan

# set +x # Ends debugging
