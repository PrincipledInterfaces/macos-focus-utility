import sys
import os
from abc import ABC, abstractmethod
from typing import Dict, List, Any
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel, QPushButton, QDialog

# Add parent directories to path to import plugin_system
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from plugin_system import PluginBase

# Import controlsniffer functions
try:
    from . import controlsniffer
    set_queued_mode = controlsniffer.set_queued_mode
    get_queued_mode = controlsniffer.get_queued_mode  
    start_mode = controlsniffer.start_mode
except ImportError:
    # Fallback if import fails
    def set_queued_mode(mode): pass
    def get_queued_mode(): return None
    def start_mode(mode): pass

# Module-level function for controlsniffer to use
def end_session_event():
    """End the current session - callable from controlsniffer"""
    try:
        from plugin_system import plugin_manager
        # Get the cs screw plugin instance
        if 'cs_marble' in plugin_manager.loaded_plugins:
            plugin_instance = plugin_manager.loaded_plugins['cs_marble']
            success = plugin_instance.end_session()
            if success:
                print("Session ended successfully")
            else:
                print("Failed to end session")
        else:
            print("cs marble plugin not loaded")
    except Exception as e:
        print(f"Error ending session: {e}")


class Plugin(PluginBase):

    def __init__(self):
        super().__init__()
        self.name = "cs marble"
        self.version = "1.0.0"
        self.description = "Support for hardware controller (ESP 8266 Version)"

    def initialize(self) -> bool:
        print("cs marble Plugin Initialized")
        return True


    def cleanup(self):
        pass

