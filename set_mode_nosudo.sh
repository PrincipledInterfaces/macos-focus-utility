#!/bin/bash

# Check if usage is correct
if [ -z "$1" ]; then
    echo "Usage: $0 <mode>"
    exit 1
fi

mode=$1

echo "$mode" > current_mode

echo "Focus mode set to: $mode"
echo "Note: Running in sudo-free mode. DNS blocking is disabled."
echo "Application monitoring and blocking will still function."

# Start the kill looper without sudo (for app monitoring only)
bash ./kill_looper_nosudo.sh &

echo "Focus mode activated successfully!"