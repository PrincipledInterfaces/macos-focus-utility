import sys
import os
import json
import requests
import socket
import threading
import time
from typing import Dict, List, Any, Optional
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QThread
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
                             QPushButton, QDialog, QScrollArea, QFrame,
                             QSlider, QCheckBox, QComboBox, QGroupBox,
                             QColorDialog, QMessageBox, QProgressBar,
                             QListWidget, QListWidgetItem, QSplitter,
                             QTextEdit, QLineEdit)
from PyQt5.QtGui import QColor, QPalette

# Add parent directories to path to import plugin_system
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from plugin_system import PluginBase

class LampDevice:
    def __init__(self, ip: str, device_id: str, name: str):
        self.ip = ip
        self.device_id = device_id
        self.name = name
        self.connected = True
        self.last_seen = time.time()
    
    def __str__(self):
        return f"{self.name} ({self.ip})"

class LampDiscoveryThread(QThread):
    device_found = pyqtSignal(object)  # LampDevice
    discovery_finished = pyqtSignal()
    
    def __init__(self):
        super().__init__()
        self.running = False
    
    def run(self):
        self.running = True
        self.discover_lamps()
        self.discovery_finished.emit()
    
    def stop(self):
        self.running = False
    
    def discover_lamps(self):
        """Scan network for Focus LED Lamps"""
        try:
            # Get local IP range
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
            
            print(f"DEBUG: Local computer IP: {local_ip}")
            
            # Get network base (assumes /24 subnet)
            ip_parts = local_ip.split('.')
            network_base = f"{ip_parts[0]}.{ip_parts[1]}.{ip_parts[2]}"
            
            print(f"DEBUG: Scanning network {network_base}.0/24 for Focus LED Lamps...")
            
            # Scan IPs 1-254 in parallel (limited threads)
            threads = []
            for i in range(1, 255):
                if not self.running:
                    break
                    
                ip = f"{network_base}.{i}"
                thread = threading.Thread(target=self.check_ip, args=(ip,))
                threads.append(thread)
                thread.start()
                
                # Limit concurrent threads
                if len(threads) >= 50:
                    for t in threads:
                        t.join()
                    threads = []
            
            # Wait for remaining threads
            for t in threads:
                t.join()
                
        except Exception as e:
            print(f"Discovery error: {e}")
    
    def check_ip(self, ip: str):
        """Check if IP has a Focus LED Lamp"""
        if not self.running:
            return
            
        try:
            response = requests.get(f"http://{ip}/discover", timeout=3)
            if response.status_code == 200:
                data = response.json()
                print(f"DEBUG: Got response from {ip}: {data}")
                if data.get('device') == 'focus_lamp':
                    device = LampDevice(
                        ip=ip,
                        device_id=data.get('id', 'unknown'),
                        name=data.get('name', 'Focus LED Lamp')
                    )
                    self.device_found.emit(device)
                    print(f"Found lamp: {device}")
        except requests.exceptions.RequestException as e:
            # Only print errors for debugging, not for every IP
            if "192.168." in ip and ip.endswith((".1", ".100", ".101", ".150")):  # Common router/device IPs
                print(f"DEBUG: No response from {ip}: {type(e).__name__}")
        except Exception as e:
            print(f"DEBUG: Unexpected error checking {ip}: {e}")

class ModeSettingsWidget(QWidget):
    def __init__(self, mode_name: str, settings: Dict):
        super().__init__()
        self.mode_name = mode_name
        self.settings = settings.copy()
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(15)
        
        # Mode title
        title = QLabel(f"{self.mode_name.title()} Mode Settings")
        title.setStyleSheet("font-size: 16px; font-weight: bold; color: #333;")
        layout.addWidget(title)
        
        # Primary color
        color_group = QGroupBox("Primary Color")
        color_layout = QHBoxLayout()
        
        self.color_button = QPushButton()
        self.color_button.setFixedSize(50, 30)
        self.update_color_button()
        self.color_button.clicked.connect(self.choose_color)
        
        color_layout.addWidget(QLabel("Color:"))
        color_layout.addWidget(self.color_button)
        color_layout.addStretch()
        color_group.setLayout(color_layout)
        layout.addWidget(color_group)
        
        # Movement slider
        movement_group = QGroupBox("Animation Movement")
        movement_layout = QVBoxLayout()
        
        self.movement_slider = QSlider(Qt.Horizontal)
        self.movement_slider.setRange(0, 100)
        self.movement_slider.setValue(self.settings.get('movement', 30))
        self.movement_slider.valueChanged.connect(self.update_movement)
        
        self.movement_label = QLabel(f"Movement: {self.movement_slider.value()}%")
        
        movement_layout.addWidget(self.movement_label)
        movement_layout.addWidget(self.movement_slider)
        movement_group.setLayout(movement_layout)
        layout.addWidget(movement_group)
        
        # Front white settings
        white_group = QGroupBox("Front White Light")
        white_layout = QVBoxLayout()
        
        self.front_white_checkbox = QCheckBox("Enable front white light")
        self.front_white_checkbox.setChecked(self.settings.get('front_white', False))
        self.front_white_checkbox.toggled.connect(self.update_front_white)
        white_layout.addWidget(self.front_white_checkbox)
        
        # White temperature slider
        temp_layout = QHBoxLayout()
        temp_layout.addWidget(QLabel("Temperature:"))
        
        self.temp_combo = QComboBox()
        temps = [
            ("1800K (Candle)", 1800),
            ("2200K (Warm)", 2200),
            ("2700K (Soft White)", 2700),
            ("3000K (Warm White)", 3000),
            ("4000K (Neutral)", 4000),
            ("5000K (Daylight)", 5000),
            ("6500K (Cool)", 6500),
            ("9000K (Blue)", 9000)
        ]
        
        current_temp = self.settings.get('white_temp', 4000)
        for name, temp in temps:
            self.temp_combo.addItem(name, temp)
            if temp == current_temp:
                self.temp_combo.setCurrentText(name)
        
        self.temp_combo.currentTextChanged.connect(self.update_white_temp)
        temp_layout.addWidget(self.temp_combo)
        temp_layout.addStretch()
        
        white_layout.addLayout(temp_layout)
        white_group.setLayout(white_layout)
        layout.addWidget(white_group)
        
        # Update visibility
        self.update_temp_visibility()
        
        layout.addStretch()
        self.setLayout(layout)
    
    def update_color_button(self):
        color = self.settings.get('primary_color', [0, 122, 255])
        self.color_button.setStyleSheet(
            f"background-color: rgb({color[0]}, {color[1]}, {color[2]}); "
            "border: 2px solid #ccc; border-radius: 4px;"
        )
    
    def choose_color(self):
        current_color = self.settings.get('primary_color', [0, 122, 255])
        color = QColorDialog.getColor(
            QColor(current_color[0], current_color[1], current_color[2]),
            self,
            "Choose Primary Color"
        )
        
        if color.isValid():
            self.settings['primary_color'] = [color.red(), color.green(), color.blue()]
            self.update_color_button()
    
    def update_movement(self, value):
        self.settings['movement'] = value
        self.movement_label.setText(f"Movement: {value}%")
    
    def update_front_white(self, checked):
        self.settings['front_white'] = checked
        self.update_temp_visibility()
    
    def update_white_temp(self):
        temp = self.temp_combo.currentData()
        if temp:
            self.settings['white_temp'] = temp
    
    def update_temp_visibility(self):
        enabled = self.front_white_checkbox.isChecked()
        self.temp_combo.setEnabled(enabled)
    
    def get_settings(self):
        return self.settings.copy()

class LampSettingsDialog(QDialog):
    def __init__(self, plugin):
        super().__init__()
        self.plugin = plugin
        self.setWindowTitle("WiFi LED Lamp Settings")
        self.setModal(True)
        self.resize(800, 700)
        self.init_ui()
    
    def init_ui(self):
        layout = QVBoxLayout()
        
        # Header
        header = QLabel("WiFi LED Lamp Configuration")
        header.setStyleSheet("font-size: 20px; font-weight: bold; margin: 10px;")
        header.setAlignment(Qt.AlignCenter)
        layout.addWidget(header)
        
        # Main content splitter
        splitter = QSplitter(Qt.Horizontal)
        
        # Left side - Device discovery and connection
        left_widget = QWidget()
        left_layout = QVBoxLayout()
        
        # Discovery section
        discovery_group = QGroupBox("Device Discovery")
        discovery_layout = QVBoxLayout()
        
        self.discovery_button = QPushButton("Scan for LED Lamps")
        self.discovery_button.clicked.connect(self.start_discovery)
        discovery_layout.addWidget(self.discovery_button)
        
        # Manual IP test section
        manual_layout = QHBoxLayout()
        manual_layout.addWidget(QLabel("Test IP:"))
        self.manual_ip_input = QLineEdit()
        self.manual_ip_input.setPlaceholderText("192.168.1.100")
        manual_layout.addWidget(self.manual_ip_input)
        
        test_ip_button = QPushButton("Test IP")
        test_ip_button.clicked.connect(self.test_manual_ip)
        manual_layout.addWidget(test_ip_button)
        discovery_layout.addLayout(manual_layout)
        
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        discovery_layout.addWidget(self.progress_bar)
        
        self.device_list = QListWidget()
        self.device_list.itemClicked.connect(self.select_device)
        discovery_layout.addWidget(self.device_list)
        
        # Connection status
        self.status_label = QLabel("No device connected")
        self.status_label.setStyleSheet("padding: 8px; background: #f0f0f0; border-radius: 4px;")
        discovery_layout.addWidget(self.status_label)
        
        # Connect/Test buttons
        button_layout = QHBoxLayout()
        self.connect_button = QPushButton("Connect to Selected")
        self.connect_button.clicked.connect(self.connect_to_device)
        self.connect_button.setEnabled(False)
        
        self.test_button = QPushButton("Test Lamp")
        self.test_button.clicked.connect(self.test_lamp)
        self.test_button.setEnabled(False)
        
        button_layout.addWidget(self.connect_button)
        button_layout.addWidget(self.test_button)
        discovery_layout.addLayout(button_layout)
        
        discovery_group.setLayout(discovery_layout)
        left_layout.addWidget(discovery_group)
        
        # Instructions
        instructions = QTextEdit()
        instructions.setMaximumHeight(200)
        instructions.setReadOnly(True)
        instructions.setHtml("""
        <h3>Setup Instructions:</h3>
        <ol>
        <li><b>Upload Arduino code:</b> Use Arduino IDE to upload the provided sketch to your ESP8266</li>
        <li><b>WiFi Setup:</b> Connect to "FocusLamp-Setup" network and configure your WiFi</li>
        <li><b>Discovery:</b> Click "Scan for LED Lamps" to find your device</li>
        <li><b>Connect:</b> Select your lamp and click "Connect to Selected"</li>
        <li><b>Configure:</b> Customize settings for each focus mode on the right</li>
        <li><b>Test:</b> Use "Test Lamp" to verify everything works</li>
        </ol>
        <p><b>Troubleshooting:</b> Make sure your ESP8266 and computer are on the same WiFi network.</p>
        """)
        left_layout.addWidget(instructions)
        
        left_widget.setLayout(left_layout)
        splitter.addWidget(left_widget)
        
        # Right side - Mode settings
        right_widget = QWidget()
        right_layout = QVBoxLayout()
        
        settings_label = QLabel("Focus Mode Lighting Settings")
        settings_label.setStyleSheet("font-size: 16px; font-weight: bold; margin: 5px;")
        right_layout.addWidget(settings_label)
        
        # Scrollable settings area
        scroll = QScrollArea()
        scroll_widget = QWidget()
        self.settings_layout = QVBoxLayout()
        
        # Load mode settings
        self.mode_widgets = {}
        self.load_mode_settings()
        
        scroll_widget.setLayout(self.settings_layout)
        scroll.setWidget(scroll_widget)
        scroll.setWidgetResizable(True)
        right_layout.addWidget(scroll)
        
        right_widget.setLayout(right_layout)
        splitter.addWidget(right_widget)
        
        # Set splitter proportions
        splitter.setSizes([400, 400])
        layout.addWidget(splitter)
        
        # Bottom buttons
        button_layout = QHBoxLayout()
        
        save_button = QPushButton("Save Settings")
        save_button.clicked.connect(self.save_settings)
        save_button.setStyleSheet("QPushButton { background: #007aff; color: white; padding: 8px 16px; border-radius: 6px; }")
        
        cancel_button = QPushButton("Cancel")
        cancel_button.clicked.connect(self.reject)
        
        button_layout.addStretch()
        button_layout.addWidget(cancel_button)
        button_layout.addWidget(save_button)
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
        
        # Initialize discovery thread
        self.discovery_thread = None
        
        # Load existing devices
        self.load_saved_devices()
    
    def load_mode_settings(self):
        """Load settings widgets for each focus mode"""
        # Default mode configurations
        default_modes = {
            'productivity': {
                'primary_color': [173, 216, 230],  # Light blue
                'movement': 20,
                'front_white': True,
                'white_temp': 4000
            },
            'creativity': {
                'primary_color': [255, 0, 255],  # Bright magenta (easier to see)
                'movement': 80,
                'front_white': False,
                'white_temp': 4000
            },
            'social_media_detox': {
                'primary_color': [255, 165, 0],    # Orange
                'movement': 50,
                'front_white': True,
                'white_temp': 2700
            }
        }
        
        # Get saved settings or use defaults
        saved_settings = self.plugin.get_setting('mode_settings', {})
        
        # Get all available modes (built-in + custom)
        all_modes = set(default_modes.keys())
        
        # Add any custom modes from the app
        try:
            # Get the plugin file path and navigate to modes/custom directory
            plugin_dir = os.path.dirname(__file__)  # /plugins/wifi_led_lamp/
            plugins_dir = os.path.dirname(plugin_dir)  # /plugins/
            project_root = os.path.dirname(plugins_dir)  # /
            custom_modes_dir = os.path.join(project_root, 'modes', 'custom')
            
            print(f"DEBUG: Looking for custom modes in: {custom_modes_dir}")
            print(f"DEBUG: Custom modes dir exists: {os.path.exists(custom_modes_dir)}")
            
            if os.path.exists(custom_modes_dir):
                files = os.listdir(custom_modes_dir)
                print(f"DEBUG: Files in custom modes dir: {files}")
                
                for file in files:
                    if file.endswith('.txt'):
                        mode_name = file[:-4]
                        all_modes.add(mode_name)
                        print(f"DEBUG: Added custom mode: {mode_name}")
        except Exception as e:
            print(f"DEBUG: Error loading custom modes: {e}")
        
        # Create widgets for each mode
        for mode in sorted(all_modes):
            if mode in saved_settings:
                settings = saved_settings[mode]
            elif mode in default_modes:
                settings = default_modes[mode].copy()
            else:
                # Default settings for custom modes
                settings = {
                    'primary_color': [128, 128, 128],  # Neutral gray
                    'movement': 30,
                    'front_white': False,
                    'white_temp': 4000
                }
            
            widget = ModeSettingsWidget(mode, settings)
            self.mode_widgets[mode] = widget
            self.settings_layout.addWidget(widget)
            
            # Add separator
            separator = QFrame()
            separator.setFrameShape(QFrame.HLine)
            separator.setStyleSheet("color: #ccc;")
            self.settings_layout.addWidget(separator)
        
        self.settings_layout.addStretch()
    
    def start_discovery(self):
        """Start device discovery"""
        if self.discovery_thread and self.discovery_thread.isRunning():
            return
        
        print("DEBUG: Starting device discovery...")
        self.discovery_button.setEnabled(False)
        self.progress_bar.setVisible(True)
        self.progress_bar.setRange(0, 0)  # Indeterminate
        self.device_list.clear()
        
        self.discovery_thread = LampDiscoveryThread()
        self.discovery_thread.device_found.connect(self.add_discovered_device)
        self.discovery_thread.discovery_finished.connect(self.discovery_complete)
        self.discovery_thread.start()
    
    def add_discovered_device(self, device: LampDevice):
        """Add discovered device to list"""
        item = QListWidgetItem(str(device))
        item.setData(Qt.UserRole, device)
        self.device_list.addItem(item)
    
    def discovery_complete(self):
        """Handle discovery completion"""
        self.discovery_button.setEnabled(True)
        self.progress_bar.setVisible(False)
        
        if self.device_list.count() == 0:
            QMessageBox.information(
                self,
                "No Devices Found",
                "No Focus LED Lamps found on the network.\\n\\n"
                "Try using 'Test IP' with your ESP8266's specific IP address, or\\n"
                "make sure your ESP8266 is connected to WiFi and running the Focus Lamp sketch."
            )
    
    def test_manual_ip(self):
        """Test a specific IP address"""
        ip = self.manual_ip_input.text().strip()
        if not ip:
            QMessageBox.warning(self, "Invalid IP", "Please enter an IP address to test.")
            return
        
        print(f"DEBUG: Testing manual IP: {ip}")
        
        try:
            response = requests.get(f"http://{ip}/discover", timeout=5)
            print(f"DEBUG: Response status: {response.status_code}")
            print(f"DEBUG: Response text: {response.text}")
            
            if response.status_code == 200:
                data = response.json()
                print(f"DEBUG: Parsed JSON: {data}")
                
                if data.get('device') == 'focus_lamp':
                    device = LampDevice(
                        ip=ip,
                        device_id=data.get('id', 'unknown'),
                        name=data.get('name', 'Focus LED Lamp')
                    )
                    self.add_discovered_device(device)
                    QMessageBox.information(self, "Success!", f"Found Focus LED Lamp at {ip}!")
                else:
                    QMessageBox.information(self, "Wrong Device", 
                                          f"Device at {ip} responded but is not a Focus LED Lamp.\\n\\n"
                                          f"Response: {data}")
            else:
                QMessageBox.warning(self, "HTTP Error", 
                                  f"Device at {ip} responded with HTTP {response.status_code}\\n\\n"
                                  f"Response: {response.text}")
        
        except requests.exceptions.ConnectTimeout:
            QMessageBox.warning(self, "Connection Timeout", 
                              f"No response from {ip} - device may be offline or not a Focus LED Lamp.")
        except requests.exceptions.ConnectionError:
            QMessageBox.warning(self, "Connection Error", 
                              f"Could not connect to {ip} - device may be offline.")
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Error testing {ip}:\\n{str(e)}")
    
    def select_device(self, item):
        """Handle device selection"""
        self.connect_button.setEnabled(True)
        device = item.data(Qt.UserRole)
        self.status_label.setText(f"Selected: {device}")
        self.status_label.setStyleSheet("padding: 8px; background: #e3f2fd; border-radius: 4px;")
    
    def connect_to_device(self):
        """Connect to selected device"""
        current_item = self.device_list.currentItem()
        if not current_item:
            return
        
        device = current_item.data(Qt.UserRole)
        
        # Test connection
        try:
            response = requests.get(f"http://{device.ip}/status", timeout=5)
            if response.status_code == 200:
                self.plugin.set_setting('connected_device', {
                    'ip': device.ip,
                    'device_id': device.device_id,
                    'name': device.name
                })
                
                self.status_label.setText(f"Connected to {device.name}")
                self.status_label.setStyleSheet("padding: 8px; background: #e8f5e8; border-radius: 4px;")
                self.test_button.setEnabled(True)
                
                QMessageBox.information(self, "Success", f"Successfully connected to {device.name}!")
            else:
                raise Exception("Device not responding")
                
        except Exception as e:
            QMessageBox.warning(
                self,
                "Connection Failed",
                f"Failed to connect to {device.name}:\\n{str(e)}"
            )
    
    def test_lamp(self):
        """Test the connected lamp"""
        device_info = self.plugin.get_setting('connected_device')
        if not device_info:
            return
        
        try:
            # Send test command
            data = {
                "command": "transition"
            }
            
            response = requests.post(
                f"http://{device_info['ip']}/control",
                json=data,
                timeout=5
            )
            
            if response.status_code == 200:
                QMessageBox.information(self, "Test Successful", "Lamp test completed! Check your lamp for the animation.")
            else:
                QMessageBox.warning(self, "Test Failed", "Failed to communicate with lamp.")
                
        except Exception as e:
            QMessageBox.warning(self, "Test Failed", f"Error testing lamp:\\n{str(e)}")
    
    def load_saved_devices(self):
        """Load previously connected devices"""
        device_info = self.plugin.get_setting('connected_device')
        if device_info:
            self.status_label.setText(f"Connected to {device_info['name']}")
            self.status_label.setStyleSheet("padding: 8px; background: #e8f5e8; border-radius: 4px;")
            self.test_button.setEnabled(True)
    
    def save_settings(self):
        """Save all mode settings"""
        mode_settings = {}
        for mode, widget in self.mode_widgets.items():
            mode_settings[mode] = widget.get_settings()
        
        self.plugin.set_setting('mode_settings', mode_settings)
        
        QMessageBox.information(self, "Settings Saved", "WiFi LED Lamp settings saved successfully!")
        self.accept()

class Plugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.name = "WiFi LED Lamp"
        self.version = "1.0.0"
        self.description = "Controls WiFi-connected ARGB LED lamp for focus mode lighting"
        
        # Plugin state
        self.current_device = None
        self.current_mode = None
        
        # Settings file path
        self.settings_file = os.path.join(os.path.dirname(__file__), 'lamp_settings.json')
        self.load_settings()
    
    def initialize(self) -> bool:
        """Initialize the plugin"""
        print(f"DEBUG: Initializing WiFi LED Lamp plugin")
        print(f"DEBUG: Plugin name: {self.name}")
        print(f"DEBUG: Plugin version: {self.version}")
        
        # Load connected device
        device_info = self.get_setting('connected_device')
        print(f"DEBUG: Device info from settings: {device_info}")
        
        if device_info:
            self.current_device = LampDevice(
                device_info['ip'],
                device_info['device_id'],
                device_info['name']
            )
            print(f"DEBUG: Loaded saved device: {self.current_device}")
        else:
            print(f"DEBUG: No saved device found")
        
        print(f"DEBUG: WiFi LED Lamp plugin initialization complete")
        return True
    
    def cleanup(self):
        """Cleanup when plugin is disabled"""
        if self.current_device:
            try:
                self.turn_off_lamp()
            except:
                pass
        self.save_settings()
    
    def get_settings_widget(self) -> QWidget:
        """Return the settings configuration widget"""
        return LampSettingsDialog(self)
    
    def configure(self):
        """Show configuration dialog"""
        dialog = LampSettingsDialog(self)
        dialog.exec_()
    
    def on_session_start(self, session_data: Dict[str, Any]):
        """Handle session start"""
        print(f"DEBUG: WiFi LED Lamp on_session_start called!")
        print(f"DEBUG: Session data: {session_data}")
        
        mode = session_data.get('mode', 'productivity')
        self.current_mode = mode
        
        print(f"DEBUG: WiFi LED Lamp - Session started with mode '{mode}'")
        print(f"DEBUG: Current device: {self.current_device}")
        
        if self.current_device:
            print(f"DEBUG: Device found, calling set_lamp_mode('{mode}')")
            self.set_lamp_mode(mode)
        else:
            print(f"DEBUG: No device connected, cannot set lamp mode")
    
    def on_session_end(self, session_data: Dict[str, Any]):
        """Handle session end"""
        print(f"DEBUG: WiFi LED Lamp on_session_end called!")
        print(f"DEBUG: Session data: {session_data}")
        self.current_mode = None
        
        if self.current_device:
            print(f"DEBUG: Turning off lamp")
            self.turn_off_lamp()
        else:
            print(f"DEBUG: No device connected, cannot turn off lamp")
    
    def on_session_update(self, elapsed_minutes: float, progress_percent: float):
        """Handle session updates - could be used for progress-based lighting"""
        pass
    
    def set_lamp_mode(self, mode: str):
        """Set the lamp to a specific focus mode"""
        if not self.current_device:
            print("DEBUG: No device connected")
            return
        
        print(f"DEBUG: Setting lamp to mode '{mode}'")
        
        # Get mode settings with proper defaults
        mode_settings = self.get_setting('mode_settings', {})
        print(f"DEBUG: Saved mode_settings: {mode_settings}")
        
        # Default mode configurations (same as in UI)
        default_modes = {
            'productivity': {
                'primary_color': [173, 216, 230],  # Light blue
                'movement': 20,
                'front_white': True,
                'white_temp': 4000
            },
            'creativity': {
                'primary_color': [255, 0, 255],  # Bright magenta (easier to see)
                'movement': 80,
                'front_white': False,
                'white_temp': 4000
            },
            'social_media_detox': {
                'primary_color': [255, 165, 0],    # Orange
                'movement': 50,
                'front_white': True,
                'white_temp': 2700
            }
        }
        
        # Use saved settings if available, otherwise use proper defaults
        if mode in mode_settings:
            settings = mode_settings[mode]
            print(f"DEBUG: Using saved settings for {mode}: {settings}")
        elif mode in default_modes:
            settings = default_modes[mode].copy()
            print(f"DEBUG: Using default settings for {mode}: {settings}")
        else:
            # Custom mode fallback
            settings = {
                'primary_color': [128, 128, 128],  # Neutral gray
                'movement': 30,
                'front_white': False,
                'white_temp': 4000
            }
            print(f"DEBUG: Using generic settings for custom mode {mode}: {settings}")
        
        # Send command to lamp
        data = {
            "command": "set_mode",
            "mode": mode,
            "primaryColor": settings['primary_color'],
            "whiteTemp": settings['white_temp'],
            "movement": settings['movement'],
            "frontWhite": settings['front_white']
        }
        
        print(f"DEBUG: Sending data to lamp: {data}")
        
        try:
            response = requests.post(
                f"http://{self.current_device.ip}/control",
                json=data,
                timeout=5
            )
            
            if response.status_code == 200:
                print(f"DEBUG: Successfully set lamp to {mode} mode")
            else:
                print(f"DEBUG: Failed to set lamp mode: HTTP {response.status_code}")
                print(f"DEBUG: Response text: {response.text}")
                
        except Exception as e:
            print(f"DEBUG: Error communicating with lamp: {e}")
    
    def turn_off_lamp(self):
        """Turn off the lamp"""
        if not self.current_device:
            return
        
        data = {"command": "turn_off"}
        
        try:
            response = requests.post(
                f"http://{self.current_device.ip}/control",
                json=data,
                timeout=5
            )
            
            if response.status_code == 200:
                print("Successfully turned off lamp")
            else:
                print(f"Failed to turn off lamp: HTTP {response.status_code}")
                
        except Exception as e:
            print(f"Error turning off lamp: {e}")
    
    def load_settings(self):
        """Load plugin settings from file"""
        try:
            if os.path.exists(self.settings_file):
                with open(self.settings_file, 'r') as f:
                    self.settings = json.load(f)
            else:
                self.settings = {}
        except Exception as e:
            print(f"Error loading settings: {e}")
            self.settings = {}
    
    def save_settings(self):
        """Save plugin settings to file"""
        try:
            with open(self.settings_file, 'w') as f:
                json.dump(self.settings, f, indent=2)
        except Exception as e:
            print(f"Error saving settings: {e}")
    
    def get_setting(self, key: str, default=None):
        """Get a setting value"""
        return self.settings.get(key, default)
    
    def set_setting(self, key: str, value):
        """Set a setting value"""
        self.settings[key] = value
        self.save_settings()