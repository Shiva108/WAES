#!/usr/bin/env bash
# Used for code testing, ignore or delete.

# vars
VERSION="0.0.31 alpha"
VULNERSDIR="vulscan" # Where to find vulscan
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

#if [[ `id -u` -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi
#
## Checks for input parameters
#: ${1?"No arguments supplied - run waes -h for help or cat README.md"}
#
#
#if [[ $1 == "-h" ]]
#  then
#    usage
#    exit 1
#fi
#
#if [[ "$1" != "-u" && "$1" != "-h" ]]; then
#   usage
#   echo "Invalid parameter: $1"
#   exit 1
#fi

# Todo: Use 1 loop for all tools
# Tools check
for i in ${TOOLS[*]}; do
echo ${TOOLS[i]}
    which {TOOLS[i]}>/dev/null
#        if [[ $? -eq 0 ]]
#                then
#                        echo ""
#        else
#                        echo ""
#                    echo -e "\e[01;31m[!]\e[00m Unable to find the required xx program, install and try again"
#                exit 1
#        fi ;
done