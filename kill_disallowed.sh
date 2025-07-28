#!/bin/bash

mode=$(cat current_mode) #reads current_mode to get mode name

allowed=$(cat "modes/$mode.txt") #checks for allowed app list in the mode text file

running=$(osascript -e 'tell application "System Events" to get name of (every process whose background only is false)') #gets all open apps in a list stored as running

for app in $(echo "$running" | tr ", " "\n"); do #converts x, y, z to have new line for each x y z
    if ! grep -qx "$app" <<<"$allowed"; then
        osascript -e "quit app \"$app\"" #quits the app if not allowed
    fi
done