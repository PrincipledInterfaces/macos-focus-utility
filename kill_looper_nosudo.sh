#!/bin/bash

echo "Starting application monitoring (sudo-free mode)..."

while true; do
    bash ./kill_disallowed.sh
    sleep 2
done