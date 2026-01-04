#!/bin/bash
# Stop the demo app
if [[ -f /tmp/waes_demo.pid ]]; then
    kill $(cat /tmp/waes_demo.pid)
    rm /tmp/waes_demo.pid
    echo "Demo app stopped."
else
    echo "No PID file found."
fi
