#!/bin/bash

#checks if usage is correct
if [ -z "$1" ]; then
    echo "Usage: $0 <mode>"
    exit 1
fi

mode=$1

echo "$mode" > current_mode

sudo cp "hosts/${mode}_hosts" /etc/hosts
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

sudo bash ./kill_looper.sh