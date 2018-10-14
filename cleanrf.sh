#!/usr/bin/env bash

echo "Clears report folder for files"
read -p "Are you sure you wish to continue? (yes/y): "
response=${response:l} #tolower
if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
    rm report/*.*
fi

echo "Done"

