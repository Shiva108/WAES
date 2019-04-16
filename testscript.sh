#!/usr/bin/env bash
# Used for code testing, ignore or delete.

# vars
VERSION="0.0.31 alpha"
VULNERSDIR="vulscan" # Where to find vulscan
REPORTDIR="report" # /report directory
TOOLS=( "nmap" "nikto" "uniscan" "gobuster" "dirb" "whatweb" "testingxxasdfd")
SECLISTDIR="SecLists" # Todo: Use var and pass to next script
count=-1

usage ()
{
echo "Usage: ${0##*/} -u {url}"
echo "       ${0##*/} -h"
echo ""
echo "       -h shows this help"
echo "       -u url to test without http or https e.g. testsite.com"
echo ""
}


#if ! hash ${TOOLS[count]} 2>/dev/null
#then
#    echo "'some_exec' was not found in PATH"
#fi

# Count the number of possible testers.
# (Loop until we find an empty string.)
#

while [[ "x${TOOLS[count]}" != "x" ]]
do
   count=$(( $count + 1 ))
   # echo ${count}
   # echo ${TOOLS[count]}
   if ! hash ${TOOLS[count]} /dev/null 2>&1
    then
        echo -e "\e[01;31m[!]\e[00m ${TOOLS[count]} was not found in PATH"
        echo "Run sudo ./install.sh to install tools"
    fi
done

