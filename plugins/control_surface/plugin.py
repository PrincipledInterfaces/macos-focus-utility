from abc import ABC, abstractmethod
from typing import Dict, List, Any
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import QWidget, QVBoxLayout, QLabel, QPushButton, QDialog
from plugin_system import PluginBase


class Plugin(PluginBase):
    
    def __init__(self):
        super().__init__()
        self.name = "Control Surface"
        self.version = "1.0.0"
        self.description = "Support for hardware controller (ESP 8266 Version)"

    def initialize(self) -> bool:
        print("Control Surface Plugin Initialized")
        return True


    def cleanup(self):
        pass
