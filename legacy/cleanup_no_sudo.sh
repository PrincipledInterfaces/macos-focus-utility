#!/bin/bash
echo "Stopping Focus Mode (no sudo)..."
> current_mode
pkill -f "kill_looper.sh" 2>/dev/null
pkill -f "kill_disallowed.sh" 2>/dev/null  
pkill -f "monitor_active_programs.sh" 2>/dev/null
sleep 1
pkill -9 -f "kill_looper" 2>/dev/null
pkill -9 -f "kill_disallowed" 2>/dev/null
pkill -9 -f "monitor_active" 2>/dev/null
echo "✅ Basic cleanup completed (hosts file not reset)"
