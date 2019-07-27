#!/usr/bin/env bash
# 2018-2019 by Shiva @ CPH:SEC
<<<<<<< HEAD

# WAES requires vulners.nse     : https://github.com/vulnersCom/nmap-vulners
# WAES requires supergobuster   : https://gist.github.com/lokori/17a604cad15e30ddae932050bbcc42f9
# WAEs requires SecLists        : https://github.com/danielmiessler/SecLists

=======
>>>>>>> 56b17398b9ba8589c6a8aa43aee0262070e1629f

# Script begins
#===============================================================================

# set -x # Starts debugging

# vars
VERSION="0.0.36 alpha"
VULNERSDIR="vulscan" # Where to find vulscan
REPORTDIR="report" # /report directory
TOOLS=( "nmap" "nikto" "uniscan" "gobuster" "dirb" "whatweb" "wafw00f" )
HTTPNSE=( "http-date,http-title,http-server-header,http-headers,http-enum,http-devframework,http-dombased-xss,http-stored-xss,http-xssed,http-cookie-flags,http-errors,http-grep,http-traceroute" )
PORT=80 # Setting std port
COUNT=-1 # For tools loop

#banner / help message
echo ""
echo -e "\e[00;32m#############################################################\e[00m"
echo ""
echo -e "	Web Auto Enum & Scanner $VERSION "
echo ""
echo -e "	Auto enums HTTP port and dumps files as result"
echo ""
echo -e "\e[00;32m#############################################################\e[00m"
echo ""

usage ()
{
echo "Usage: ${0##*/} -u {url}"
echo "       ${0##*/} -h"
echo ""
echo "       -h shows this help"
echo "       -u IP to test eg. 10.10.10.123"
echo "       -p port number (default=80)"
echo ""
echo "       Example: ./waes.sh -u 10.10.10.130 -p 8080"
echo ""
}

if [[ `id -u` -ne 0 ]] ; then echo -e "\e[01;31m[!]\e[00m This program must be run as root. Run again with 'sudo'" ; exit 1 ; fi

# Checks for input parameters
: ${1?"No arguments supplied - run waes -h for help or cat README.md"}

# Showing parameters - for debugging only
#echo "Positional Parameters"
#echo '$0 = ' $0
#echo '$1 = ' $1
#echo '$2 = ' $2
#echo '$3 = ' $3
#echo '$4 = ' $4

# Parameters check
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

if [[ "$3" = "-p" && "$4" != "" ]]; then
        PORT="$4"
        # echo "Port is set to: " $PORT
fi

# Tools installed check
while [[ "x${TOOLS[COUNT]}" != "x" ]]
do
   COUNT=$(( $COUNT + 1 ))
   if ! hash ${TOOLS[COUNT]} /dev/null 2>&1
    then
        echo -e "\e[01;31m[!]\e[00m ${TOOLS[COUNT]} was not found in PATH"
        echo "Run sudo ./install.sh to install tools"
    fi
done

echo " "
echo -e "Target: $2 port: $PORT"

# Todo: Implement progressbar (bartest.sh)

passive() {

    echo "Starting PASSIVE scans..."
    # Whatweb
    echo -e "\e[00;32m [+] Looking up "$2" with whatweb - only works for online targets" "\e[00m"
    whatweb -a 3 $2":"$PORT | tee ${REPORTDIR}/$2_whatweb.txt

    # OSIRA - For subdomain enum
    echo -e "\e[00;32m [+] OSIRA against:" $2 " - looking for subdomains \e[00m"
    OSIRA/osira.sh -u $2":"$PORT | tee ${REPORTDIR}/$2_osira.txt
}

fastscan() {

    echo "Step 1: Starting fast scan... "
    # wafw00f
    echo -e "\e[00;32m [+] Detecting firewall "$2":"$PORT" with wafw00f" "\e[00m"
    wafw00f -a -v $2":"$PORT | tee $REPORTDIR/$2_wafw00f.txt
    # nmap http-enum
    echo -e "\e[00;32m [+] nmap with HTTP-ENUM script against $2" "\e[00m"
    nmap -sSV -Pn -T4 -p $PORT --script http-enum $2 -oA ${REPORTDIR}/$2_nmap_http-enum
}

scan() {

    echo "Step 2: Starting more in-depth scan... "
    # nmap
    echo -e "\e[00;32m [+] nmap with various HTTP scripts against $2" "\e[00m"
    nmap -sSV -Pn -T4 -p $PORT --script $HTTPNSE $2 -oA ${REPORTDIR}/$2_nmap_http-va
    echo -e "\e[00;32m [+] nmap with vulscan on $2 with min CVSS 5.0" "\e[00m"
    nmap -sSV -Pn -O -T4 --version-all -p $PORT --script ${VULNERSDIR}/vulscan.nse $2 --script-args mincvss=5-0 -oA ${REPORTDIR}/$2_nmap_vulners

    # nikto
    echo -e "\e[00;32m [+] nikto on $2" "\e[00m"
    nikto -h $2 -port $PORT -C all -ask no -evasion A | tee $REPORTDIR/$2_nikto.txt

    # uniscan
    echo -e "\e[00;32m [+] uniscan of $2" "\e[00m"
    uniscan -u $2":"$PORT -qweds | tee $REPORTDIR/$2_uniscan.txt
}

fuzzing() {

    echo "Step 3: Starting fuzzing... "
    # xsser
    # echo -e "\e[00;32m [+] xsser on $2" "\e[00m"
    # Todo: Implement Xsser (requires url not ip)

    # Supergobuster: gobuster + dirb
    echo -e "\e[00;32m [+] super go busting $2" "\e[00m"
    ./supergobuster.sh "http://"$2":"$PORT | tee $REPORTDIR/$2_supergobust.txt
}

end() {
    echo -e "\e[00;32m [+] WAES is done. Find results in:" ${REPORTDIR} "\e[00m"
}

# passive  $1 $2 $3 $4 # Uncomment to run, work online for online targets Todo: Add in next version
fastscan $1 $2 $3 $4
scan $1 $2 $3 $4
fuzzing  $1 $2 $3 $4
end $1 $2 $3 $4

# Todo: Add from rapidscan / golismero and others

<<<<<<< HEAD
#
echo -e "Target: $2 "

# Whatweb
echo -e "\e[00;32m [+] Looking up "$2" with whatweb" "\e[00m"
whatweb -a3 $2 | tee ${REPORTDIR}/$2_whatweb.txt

# echo -e "\e[00;32m [+] OSIRA against:" $2 "\e[00m"
# OSIRA/osira.sh -u $2 | tee ${REPORTDIR}/$2_osira.txt
# mv $2.txt ${REPORTDIR}/$2_osira.txt

# nmap
echo -e "\e[00;32m [+] nmap with standard scripts (-sC) on $2" "\e[00m"
nmap -sSCV -Pn -T4 $2 -oA ${REPORTDIR}/$2_nmap_sSCV
echo -e "\e[00;32m [+] nmap with http-enum against $2" "\e[00m"
nmap -sSV -Pn -T4 --script http-enum $2 -oA ${REPORTDIR}/$2_nmap_http-enum
# echo -e "\e[00;32m [+] nmap with various HTTP scripts against $2" "\e[00m"
# nmap -sSV -Pn -T4 --script "http-*" $2 -oA ${REPORTDIR}/$2_nmap_http-va
# echo -e "\e[00;32m [+] nmap with vulners on $2" "\e[00m"
#echo ${VULNERSDIR}"/vulners.nse"
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
=======
# set +x # Ends debugging
>>>>>>> 56b17398b9ba8589c6a8aa43aee0262070e1629f
