#!/bin/bash

# Clear current mode
> current_mode

# Kill all background focus processes
pkill -f "monitor_active_programs.sh"
pkill -f "kill_looper.sh" 
pkill -f "kill_looper_nosudo.sh"
pkill -f "kill_disallowed.sh"

# Reset hosts file
sudo bash -c 'cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
EOF'

sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

echo "Focus utility disabled. All background processes stopped. Host files have been reset."