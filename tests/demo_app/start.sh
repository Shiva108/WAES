#!/bin/bash
# Start the demo app in background
python3 tests/demo_app/vulnerable_app.py > /tmp/waes_demo.log 2>&1 &
echo $! > /tmp/waes_demo.pid
echo "Demo app started on http://localhost:8080 (PID: $(cat /tmp/waes_demo.pid))"
