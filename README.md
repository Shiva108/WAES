
![GitHub Logo](banner.png)

## To install:

1. $> git clone https://github.com/Shiva108/WAES.git
2. $> sudo ./install.sh

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
       

### Enumeration Process / Method

WAES runs ..

+ whatweb - aggressive mode
+ OSIRA (same author) - looks for subdomains
+ nmap
  - with NSE scripts: http-date,http-title,http-server-header,http-headers,http-enum,http-devframework,http-dombased-xss,http-stored-xss,http-xssed,http-cookie-flags,http-errors,http-grep,http-traceroute
  - vulscan (CVSS 5.0+)
+ nikto - with evasion A and all CGI dirs
+ uniscan - all tests except stress test
+ super gobuster
  - gobuster with multiple lists
  - dirb with multiple lists


.. against target while dumping results files in report/ folder.


### To Do
+ ...
