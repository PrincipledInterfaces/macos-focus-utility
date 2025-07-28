#!/bin/bash

echo "Flushing DNS cache to apply new website blocks..."

# Flush DNS cache on macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Clear browser caches (optional - user can do this manually)
echo "DNS cache flushed successfully!"
echo "For immediate effect, you may need to:"
echo "1. Close and reopen your browser"
echo "2. Or clear your browser's cache/cookies"
echo "3. Or restart your browser completely"