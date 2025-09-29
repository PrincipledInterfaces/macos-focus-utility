#!/bin/bash

ACTIVE_PROGRAMS_FILE="active_programs.log"
BROWSER_TABS_FILE="browser_tabs.log"

get_active_programs() {
    local programs=$(osascript -e '
        tell application "System Events"
            set activeProcesses to {}
            set allProcesses to (every process whose background only is false)
            repeat with aProcess in allProcesses
                set processName to name of aProcess
                if processName is not in {"Finder", "Dock", "SystemUIServer", "WindowServer", "loginwindow", "launchd", "kernel_task", "System Events", "ControlCenter", "NotificationCenter", "Spotlight", "Siri", "Activity Monitor"} then
                    set end of activeProcesses to processName
                end if
            end repeat
            return activeProcesses
        end tell
    ')
    echo "$programs"
}

get_safari_tabs() {
    # Check if Safari is actually running (not just available)
    if pgrep -x "Safari" > /dev/null 2>&1; then
        osascript -e '
            try
                tell application "System Events"
                    if exists (process "Safari") then
                        tell application "Safari"
                            if (count of windows) > 0 then
                                set tabTitles to {}
                                repeat with aWindow in windows
                                    repeat with aTab in tabs of aWindow
                                        set end of tabTitles to name of aTab
                                    end repeat
                                end repeat
                                return tabTitles
                            end if
                        end tell
                    end if
                end tell
            end try
        ' 2>/dev/null || echo ""
    else
        echo ""
    fi
}

get_chrome_tabs() {
    # Check if Chrome is actually running (not just available)
    if pgrep -x "Google Chrome" > /dev/null 2>&1; then
        osascript -e '
            try
                tell application "System Events"
                    if exists (process "Google Chrome") then
                        tell application "Google Chrome"
                            if (count of windows) > 0 then
                                set tabTitles to {}
                                repeat with aWindow in windows
                                    repeat with aTab in tabs of aWindow
                                        set end of tabTitles to title of aTab
                                    end repeat
                                end repeat
                                return tabTitles
                            end if
                        end tell
                    end if
                end tell
            end try
        ' 2>/dev/null || echo ""
    else
        echo ""
    fi
}

get_firefox_tabs() {
    # Check if Firefox is actually running (not just available)
    if pgrep -x "Firefox" > /dev/null 2>&1; then
        osascript -e '
            try
                tell application "System Events"
                    if exists (process "Firefox") then
                        tell application "Firefox"
                            if (count of windows) > 0 then
                                set tabTitles to {}
                                repeat with aWindow in windows
                                    repeat with aTab in tabs of aWindow
                                        set end of tabTitles to name of aTab
                                    end repeat
                                end repeat
                                return tabTitles
                            end if
                        end tell
                    end if
                end tell
            end try
        ' 2>/dev/null || echo ""
    else
        echo ""
    fi
}

log_active_programs() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local programs=$(get_active_programs)
    echo "[$timestamp] Active Programs: $programs" >> "$ACTIVE_PROGRAMS_FILE"
}

log_browser_tabs() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local safari_tabs=$(get_safari_tabs)
    if [[ -n "$safari_tabs" ]]; then
        echo "[$timestamp] Safari Tabs: $safari_tabs" >> "$BROWSER_TABS_FILE"
    fi
    
    local chrome_tabs=$(get_chrome_tabs)
    if [[ -n "$chrome_tabs" ]]; then
        echo "[$timestamp] Chrome Tabs: $chrome_tabs" >> "$BROWSER_TABS_FILE"
    fi
    
    local firefox_tabs=$(get_firefox_tabs)
    if [[ -n "$firefox_tabs" ]]; then
        echo "[$timestamp] Firefox Tabs: $firefox_tabs" >> "$BROWSER_TABS_FILE"
    fi
}

monitor_loop() {
    while true; do
        log_active_programs
        log_browser_tabs
        sleep 5
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_loop
fi