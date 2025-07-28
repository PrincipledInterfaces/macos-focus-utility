#!/bin/bash

> current_mode

sudo bash -c 'cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
EOF'

sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

echo "Focus utility disabled. Host files have been reset."