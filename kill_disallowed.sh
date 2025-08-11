#!/bin/bash

# Check if current_mode file exists and is not empty
if [ ! -s "current_mode" ]; then
    echo "No active focus mode. Exiting."
    exit 0
fi

mode=$(cat current_mode) #reads current_mode to get mode name

# Check if mode file exists
if [ ! -f "modes/$mode.txt" ]; then
    echo "Mode file modes/$mode.txt not found. Exiting."
    exit 1
fi

allowed=$(cat "modes/$mode.txt") #checks for allowed app list in the mode text file

# Essential apps that should never be killed (safety list)
essential_apps=("Finder" "SystemUIServer" "Dock" "loginwindow" "WindowServer" "Terminal" "osascript" "System Events" "Python" "focus_launcher")

running=$(osascript -e 'tell application "System Events" to get name of (every process whose background only is false)' 2>/dev/null) #gets all open apps in a list stored as running

# Check if the osascript command failed
if [ $? -ne 0 ] || [ -z "$running" ]; then
    echo "Failed to get running apps. Skipping this cycle."
    exit 0
fi

# Process the comma-separated list more carefully
# Split only on commas, not spaces, since app names can contain spaces
IFS=',' read -ra RUNNING_APPS <<< "$running"

for app in "${RUNNING_APPS[@]}"; do
    # Remove any quotes or extra whitespace
    app=$(echo "$app" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"//;s/"$//')
    
    # Skip essential apps
    skip_app=false
    for essential in "${essential_apps[@]}"; do
        if [[ "$app" == "$essential" ]]; then
            skip_app=true
            break
        fi
    done
    
    if [[ "$skip_app" == true ]]; then
        continue
    fi
    
    # Check if app is in allowed list (case-insensitive and flexible matching)
    if ! grep -qix "$app" <<<"$allowed"; then
        echo "Quitting disallowed app: $app"
        osascript -e "quit app \"$app\"" 2>/dev/null #quits the app if not allowed
    fi
done