#!/usr/bin/env bash

# vars
PORT=80 # Setting std port Todo: Implement PORT var
COUNT=-1 # For tools loop

# Showing parameters - for debugging only
echo "Positional Parameters"
echo '$0 = ' $0
echo '$1 = ' $1
echo '$2 = ' $2
echo '$3 = ' $3
echo '$4 = ' $4


echo "Port is set to: " $PORT


echo " "
echo -e "Target: " $2 " port: $PORT"