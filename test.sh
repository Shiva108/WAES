#!/usr/bin/env bash

# Check input parameters
#if [ $ -eq 0 ]
  then
    usage
    echo "No arguments supplied"
    exit 1
fi

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