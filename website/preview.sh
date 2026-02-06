#!/bin/bash

# TOME Website - Local Preview Script
# Starts a local server and opens the website in your default browser

echo "🚀 Starting TOME website preview..."
echo ""

# Check if port 8000 is already in use
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Port 8000 is already in use!"
    echo "   Stopping existing server..."
    kill $(lsof -t -i:8000) 2>/dev/null
    sleep 1
fi

# Start the server
echo "📡 Starting local server on http://localhost:8000"
python3 -m http.server 8000 > /dev/null 2>&1 &
SERVER_PID=$!

# Wait a moment for server to start
sleep 2

# Open in default browser
echo "🌐 Opening website in your browser..."
open http://localhost:8000

echo ""
echo "✅ Preview server is running!"
echo "   URL: http://localhost:8000"
echo "   PID: $SERVER_PID"
echo ""
echo "📌 Press Ctrl+C to stop the server"
echo ""

# Keep script running and handle Ctrl+C
trap "echo ''; echo '🛑 Stopping server...'; kill $SERVER_PID 2>/dev/null; echo '✅ Server stopped'; exit 0" INT

# Wait for server process
wait $SERVER_PID
