#!/bin/bash

# Standard directories for lists    : SecLists/Discovery/Web-Content & SecLists/Discovery/Web-Content/CMS
# Kali / Parrot directory list      : /usr/share/wordlists/dirbuster/

set -eu

URL=$1

<<<<<<< HEAD
echo "super go bustering for super brute: -u $URL"

gobuster  dir -u $URL -w /home/e/CTF-notes/SecLists/Discovery/Web-Content/tomcat.txt --wildcard
gobuster  dir -u $URL -w /home/e/CTF-notes/SecLists/Discovery/Web-Content/nginx.txt --wildcard
gobuster  dir -u $URL -w /home/e/CTF-notes/SecLists/Discovery/Web-Content/apache.txt --wildcard
gobuster  dir -u $URL -w /home/e/CTF-notes/SecLists/Discovery/Web-Content/RobotsDisallowed-Top1000.txt --wildcard
gobuster  dir -u $URL  -w /home/e/CTF-notes/SecLists/Discovery/Web-Content/ApacheTomcat.fuzz.txt --wildcard
# gobuster  dir -u $URL  -w /home/e/CTF-notes/SecLists/Discovery/Web_Content/sharepoint.txt --wildcard
gobuster  dir -u $URL  -w /home/e/CTF-notes/SecLists/Discovery/Web-Content/iis.txt --wildcard
gobuster  dir -u $URL  -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt --wildcard
gobuster  dir -u $URL  -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e -x txt  --wildcard
gobuster  dir -u $URL  -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e -x php --wildcard
gobuster  dir -u $URL  -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e -x doc --wildcard
gobuster  dir -u $URL  -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e -x docx --wildcard
=======
echo "super gobustering for super brute: $URL"

gobuster -u $URL -l -s 200,204,301,302,307,403 -w SecLists/Discovery/Web-Content/tomcat.txt
gobuster -u $URL -l -s 200,204,301,302,307,403 -w SecLists/Discovery/Web-Content/nginx.txt
gobuster -u $URL -l -s 200,204,301,302,307,403 -w SecLists/Discovery/Web-Content/apache.txt
gobuster -u $URL -l -s 200,204,301,302,307,403 -w SecLists/Discovery/Web-Content/RobotsDisallowed-Top1000.txt
gobuster -u $URL -l -s 200,204,301,302,307,403 -w SecLists/Discovery/Web-Content/ApacheTomcat.fuzz.txt
gobuster -u $URL -l -s 200,204,301,302,307,403 -w SecLists/Discovery/Web-Content/CMS/sharepoint.txt
gobuster -u $URL -l -s 200,204,301,302,307,403 -w /usr/share/dirb/wordlists/vulns/iis.txt
gobuster -u $URL -l -s 200,204,301,302,307,403 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
gobuster -u $URL -l -s 200,204,301,302,307,403 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e -x txt
gobuster -u $URL -l -s 200,204,301,302,307,403 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e -x php
gobuster -u $URL -l -s 200,204,301,302,307,403 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e -x doc
gobuster -u $URL -l -s 200,204,301,302,307,403 -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e -x docx
>>>>>>> 56b17398b9ba8589c6a8aa43aee0262070e1629f
