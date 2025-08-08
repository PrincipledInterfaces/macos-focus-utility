import sys
import os
from abc import ABC, abstractmethod
from typing import Dict, List, Any
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel, QPushButton, QDialog
import serial
import serial.tools.list_ports

# Add parent directories to path to import plugin_system
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from plugin_system import PluginBase

def find_esp8266():
    """Find ESP8266 device port"""
    ports = serial.tools.list_ports.comports()
    for port in ports:
        # Match by known identifiers for ESP boards
        if ('USB' in port.description or 'wch' in port.description.lower() 
            or 'ESP' in port.description or 'usbserial' in port.device):
            return port.device
    return None

def connect_to_esp():
    """Attempt to connect to ESP8266, return serial object or None"""
    port = find_esp8266()
    if not port:
        return None
        
    try:
        ser = serial.Serial(port, 115200, timeout=1)
        print(f"✅ Connected to ESP8266 at {port}")
        return ser
    except Exception as e:
        print(f"❌ Failed to connect to {port}: {e}")
        return None

def is_esp_connected(ser):
    """Check if ESP connection is still valid"""
    if ser is None:
        return False
    try:
        return ser.is_open
    except:
        return False

ser = None  # Global serial object

class Plugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.name = "LED Progressbar"
        self.version = "1.0.0"
        self.description = "Support for LED Progressbar (ESP 8266 Version)"

    def initialize(self) -> bool:
        global ser
        ser = connect_to_esp()
        print("LED Progressbar Plugin Initialized")
        if is_esp_connected(ser):
            ser.write(b"progress:0\n")
        return True

    def cleanup(self):
        global ser
        if is_esp_connected(ser):
            ser.write(b"progress:0\n")
            ser.close()

    def on_checklist_item_changed(self, item_text: str, is_checked: bool):
        global ser
        print(f"DEBUG: LED plugin checklist hook called - item: '{item_text}', checked: {is_checked}")
        if is_checked and is_esp_connected(ser):
            print("DEBUG: Sending boxchecked command to ESP")
            ser.write(b"boxchecked\n")  # Add newline character
            ser.flush()  # Ensure data is sent immediately
        else:
            if not is_checked:
                print("DEBUG: Item was unchecked, not sending command")
            if not is_esp_connected(ser):
                print("DEBUG: ESP not connected, cannot send command")

    def on_session_update(self, elapsed_minutes: float, progress_percent: float):
        global ser
        print(f"DEBUG: Session update - progress: {progress_percent}%, ESP connected: {is_esp_connected(ser)}")
        
        # Try to reconnect if not connected
        if not is_esp_connected(ser):
            print("DEBUG: ESP not connected, attempting reconnection...")
            ser = connect_to_esp()
        
        if is_esp_connected(ser):
            command = f"progress:{int(progress_percent)}\n".encode()  # Add newline
            print(f"DEBUG: Sending command: {command}")
            ser.write(command)
            ser.flush()
        else:
            print("DEBUG: Could not establish ESP connection for progress update")
    
    def on_session_end(self, session_data: Dict[str, Any]):
        """Turn off LEDs when session ends"""
        global ser
        print("DEBUG: Session ended, turning off LEDs")
        
        # Try to reconnect if not connected
        if not is_esp_connected(ser):
            print("DEBUG: ESP not connected, attempting reconnection for cleanup...")
            ser = connect_to_esp()
        
        if is_esp_connected(ser):
            print("DEBUG: Sending progress:0 to turn off LEDs")
            ser.write(b"progress:0\n")
            ser.flush()
        else:
            print("DEBUG: Could not establish ESP connection for cleanup")
