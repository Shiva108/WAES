
![GitHub Logo](banner.png)

## CPH:SEC WAES at a Glance

Doing HTB or other CTFs enumeration against targets with HTTP(S) can become trivial.
It can get tiresome to always run the same script/tests on every box eg. nmap, nikto, dirb and so on. A one-click on target with automatic reports coming solves the issue. Furthermore, with a script the enum process can be optimized while saving time for hacker. This is what **CPH:SEC WAES** or _Web Auto Enum & Scanner_ is created for. WAES runs 4 steps of scanning against target (see more below) to optimize the time spend scanning. While multi core or multi-threaded scanning could be implemented it will almost surely get boxes to hang and so is undesirable.
* From current version and forward WAES will include an install script (see blow) as project moves from alpha to beta phase.
* WAES could have been developed in python but good bash projects are need to learn bash.
* WAES is currently made for CTF boxes but is moving towards online uses (see todo section)

## To install:

```
1. $> git clone https://github.com/Shiva108/WAES.git
2. $> cd WAES
2. $> sudo ./install.sh
```

Make sure directories are set correctly in supergobuster.sh.
Should be automatic with Kali & Parrot Linux.
* Standard directories for lists    : SecLists/Discovery/Web-Content & SecLists/Discovery/Web-Content/CMS
* Kali / Parrot directory list      : /usr/share/wordlists/dirbuster/


## To run WAES
Web Auto Enum &amp; Scanner - Auto enums website(s) and dumps files as result.

##############################################################################

        Web Auto Enum & Scanner

        Auto enums website(s) and dumps files as result

##############################################################################

Usage: waes.sh -u {IP}
       waes.sh -h

       -h shows this help
       -u IP to test eg. 10.10.10.123
       -p port nummer (default=80)

       Example: ./waes.sh -u 10.10.10.130 -p 8080


## Enumeration Process / Method

WAES runs ..

Step 0 - Passive scan - (disabled in the current version)
  + whatweb - aggressive mode
  + OSIRA (same author) - looks for subdomains
Step 1 - Fast scan
  + wafw00 - firewall detection
  + nmap with http-enum
Step 2 - Scan - in-depth
  + nmap - with NSE scripts: http-date,http-title,http-server-header,http-headers,http-enum,http-devframework,http-dombased-xss,http-stored-xss,http-xssed,http-cookie-flags,http-errors,http-grep,http-traceroute
  + nmap with vulscan (CVSS 5.0+)
  + nikto - with evasion A and all CGI dirs
  + uniscan - all tests except stress test (qweds)
Step 3 - Fuzzing
+ super gobuster
  - gobuster with multiple lists
  - dirb with multiple lists
+ xss scan (to come)

.. against target while dumping results files in report/ folder.


## To Do
+ Implement domain as input
+ Add XSS scan
+ Add SSL/TLS scanning
+ Add domain scans
+ Add golismero
+ Add dirble
+ Add progressbar
+ Add CMS detection
+ Add CMS specific scans
