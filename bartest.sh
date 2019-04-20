#!/usr/bin/env bash

# For testing, ignore or delete.
# https://github.com/phenonymous/shell-progressbar


. <(curl -sLo- "https://git.io/progressbar")

bar::start

StuffToDo=("wafw00f" "http-enum" "http-nse-va" "vulscan" "nikto" "uniscan" "supergobuster" )

TotalSteps=${#StuffToDo[@]}

for Stuff in ${StuffToDo[@]}; do
  # Do stuff
  echo "Invoking ${Stuff} for scanning..."
  StepsDone=$((${StepsDone:-0}+1))
  bar::status_changed $StepsDone $TotalSteps
  sleep 1
done

bar::stop