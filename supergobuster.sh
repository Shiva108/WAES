#!/bin/bash
set -eu

URL=$1

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
