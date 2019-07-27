**Note:** Make sure directories are correct in supergobuster.sh

## WAES
Web Auto Enum &amp; Scanner - Auto enums website(s) and dumps files as result.

########################################################################

        Web Auto Enum & Scanner

        Auto enums website(s) and dumps files as result

########################################################################

Usage: waes.sh -u {url}
       waes.sh -h

       -h shows this help
       -u url to test without http or https e.g. google.com



### Method

WAES runs ..

+ whatweb
+ OSIRA (same author)
+ nmap
  - standard scripts (-sC)
  - http-enum
  - vulners.nse
+ nikto
+ uniscan
+ super gobuster
  - gobuster with multiple lists
  - dirb with multiple lists


.. against target while dumping results files in report/ folder.


### To Do
+ Simplify tools check
+ Adding FD tools: https://github.com/chrispetrou/FDsploit



