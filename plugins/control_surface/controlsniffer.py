#!/usr/bin/env python3

import serial
import serial.tools.list_ports
import os
import time
import subprocess
import sys

# Add current directory to path so we can import from plugin.py
sys.path.append(os.path.dirname(__file__))

# Simple end session function that works without complex imports
def end_session_event():
    """End the current session"""
    try:
        print("DEBUG: end_session_event called")
        # Create a stop signal file that the focus session will check for
        script_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        stop_signal_file = os.path.join(script_dir, 'stop_signal')
        
        print(f"DEBUG: Creating stop signal file at: {stop_signal_file}")
        # Create the stop signal file
        with open(stop_signal_file, 'w') as f:
            f.write('stop')
        
        # Wait a moment to ensure the signal is processed
        import time
        time.sleep(0.5)  # Half second delay
        
        print("Session end signal sent successfully")
    except Exception as e:
        print(f"Error ending session: {e}")

#open queued mode file, overwrite as blank.

def is_session_actually_running():
    """Check if there's a real active session (both file and process)"""
    script_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    current_mode_file = os.path.join(script_dir, 'current_mode')
    
    print(f"DEBUG: Checking for current_mode file at: {current_mode_file}")
    print(f"DEBUG: File exists: {os.path.exists(current_mode_file)}")
    
    # Check if there's actually a focus session process running
    focus_process_running = False
    try:
        result = subprocess.run(['pgrep', '-f', 'focusmode|focus_launcher'], 
                              capture_output=True, text=True)
        focus_process_running = bool(result.stdout.strip())
        print(f"DEBUG: Focus process running: {focus_process_running}")
    except:
        pass
    
    # Clean up leftover file if no process is running
    if os.path.exists(current_mode_file) and not focus_process_running:
        print("DEBUG: Leftover current_mode file found, cleaning up")
        try:
            os.remove(current_mode_file)
        except:
            pass
        return False
    
    return os.path.exists(current_mode_file) and focus_process_running

def find_esp8266():
    ports = serial.tools.list_ports.comports()
    for port in ports:
        # Match by known identifiers for ESP boards
        if ('USB' in port.description or 'wch' in port.description.lower() 
            or 'ESP' in port.description or 'usbserial' in port.device):
            return port.device
    return None

port = find_esp8266()
if not port:
    print("ESP8266 not found.")
    exit()

ser = serial.Serial(port, 9600, timeout=1)

queued_mode = None
waiting_for_session_end = False
session_end_start_time = None

def set_queued_mode(mode):
    global queued_mode, waiting_for_session_end, session_end_start_time
    queued_mode = mode
    waiting_for_session_end = True
    import time
    session_end_start_time = time.time()
    print(f"DEBUG: Started waiting for session to end, will start {mode} mode after")

def get_queued_mode():
    return queued_mode

def check_and_start_queued_mode():
    """Check if we're waiting for a session to end and start queued mode if ready"""
    global waiting_for_session_end, queued_mode, session_end_start_time
    
    if not waiting_for_session_end or not queued_mode:
        return
    
    # Check if session has actually ended (no focus process running)
    try:
        result = subprocess.run(['pgrep', '-f', 'focusmode|focus_launcher'], 
                              capture_output=True, text=True)
        focus_process_running = bool(result.stdout.strip())
        
        if not focus_process_running:
            # Session has ended, wait a bit more for summary to be closed, then start queued mode
            import time
            elapsed = time.time() - session_end_start_time
            if elapsed > 3:  # Wait at least 3 seconds after session ended
                print(f"DEBUG: Session ended, starting queued mode: {queued_mode}")
                mode_to_start = queued_mode
                queued_mode = None
                waiting_for_session_end = False
                session_end_start_time = None
                start_mode(mode_to_start)
    except:
        pass

def start_mode(mode):
    """Start focus mode using hybrid CLI (skips mode selection, shows other UI)"""
    try:
        script_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        focusmode_path = os.path.join(script_dir, 'focusmode.py')
        
        print(f"DEBUG: start_mode called for {mode}")
        print(f"DEBUG: script_dir = {script_dir}")
        print(f"DEBUG: focusmode_path = {focusmode_path}")
        print(f"DEBUG: focusmode.py exists = {os.path.exists(focusmode_path)}")
        
        print(f"Starting {mode} mode in hybrid mode (with UI)...")
        # Use hybrid mode - shows duration picker and goals dialog
        process = subprocess.Popen([sys.executable, focusmode_path, mode], 
                        cwd=script_dir,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE)
        
        print(f"DEBUG: Process started with PID: {process.pid}")
        print(f"{mode.title()} mode started with UI dialogs")
    except Exception as e:
        print(f"Error starting {mode} mode: {e}")
        import traceback
        traceback.print_exc()

def button_1_action():
    if is_session_actually_running():
        print("DEBUG: Active session detected, ending current session")
        end_session_event()
        set_queued_mode("productivity")
    else:
        print("DEBUG: No active session, starting productivity mode")
        start_mode("productivity")

def button_2_action():
    if is_session_actually_running():
        print("DEBUG: Active session detected, ending current session")
        end_session_event()
        set_queued_mode("creativity")
    else:
        print("DEBUG: No active session, starting creativity mode")
        start_mode("creativity")

def button_3_action():
    if is_session_actually_running():
        print("DEBUG: Active session detected, ending current session")
        end_session_event()
        set_queued_mode("social")
    else:
        print("DEBUG: No active session, starting social mode")
        start_mode("social")

#loop check for button signals
print(f"Connected to {port}")
while True:
    # Check if we need to start a queued mode
    check_and_start_queued_mode()
    
    if ser.in_waiting:
        line = ser.readline().decode().strip()
        print(f"Received: {line}")
        if line == "button1":
            button_1_action()
        elif line == "button2":
            button_2_action()
        elif line == "button3":
            button_3_action()
    
    # Small delay to prevent excessive CPU usage
    import time
    time.sleep(0.1)

