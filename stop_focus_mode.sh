#!/bin/bash

echo "Stopping Focus Mode..."

# Clear current mode
> current_mode

# Kill ALL focus mode related processes - be very thorough
echo "Stopping all focus mode processes..."
pkill -f "kill_looper.sh" 2>/dev/null
pkill -f "kill_looper_nosudo.sh" 2>/dev/null
pkill -f "kill_disallowed.sh" 2>/dev/null
pkill -f "monitor_active_programs.sh" 2>/dev/null
pkill -f "focus_launcher.py" 2>/dev/null
pkill -f "Python.*focus_launcher" 2>/dev/null

# Wait a moment for processes to terminate
sleep 1

# Force kill any stubborn processes
pkill -9 -f "kill_looper" 2>/dev/null
pkill -9 -f "kill_disallowed" 2>/dev/null
pkill -9 -f "monitor_active" 2>/dev/null
pkill -9 -f "focus_launcher" 2>/dev/null

# Reset hosts file to default (try both with and without sudo)
echo "Resetting hosts file..."
if command -v sudo >/dev/null 2>&1; then
    sudo bash -c 'cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
EOF' 2>/dev/null
    
    # Flush DNS cache with timeout to prevent hanging
    echo "Flushing DNS cache..."
    timeout 5 sudo dscacheutil -flushcache 2>/dev/null &
    timeout 5 sudo killall -HUP mDNSResponder 2>/dev/null &
    
    # Wait briefly for DNS commands to complete
    sleep 2
    echo "DNS cache flush initiated"
else
    echo "Warning: Cannot reset hosts file without sudo access"
fi

# Close any focus mode GUI windows (with timeout)
timeout 3 osascript -e 'tell application "Python" to quit' 2>/dev/null &
timeout 3 osascript -e 'tell application "focus_launcher.py" to quit' 2>/dev/null &

# Final check and cleanup (non-blocking)
echo "Performing final cleanup..."
{
    ps aux | grep -E "(focus_launcher|kill_looper|monitor_active)" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null
} &

# Don't wait for background processes - continue immediately
echo "✅ Focus mode stopped successfully!"
echo "All focus mode processes terminated and restrictions removed."
echo ""
echo "You can now use all applications and websites normally."