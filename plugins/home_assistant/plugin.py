"""
Home Assistant Integration Plugin

Activates Home Assistant scenes/presets based on focus modes to create 
custom smart home environments for different types of work sessions.

Features:
- Activates different HA scenes for each focus mode
- Returns to default scene when session ends
- Configurable scene names per mode
- Auto-discovery of Home Assistant instance
- Support for long-lived access tokens
"""

import os
import sys
import json
import requests
import time
from typing import Dict, Optional, Any

# Add the parent directory to the Python path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import PyQt5 for configuration dialog
try:
    from PyQt5.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel, 
                                 QPushButton, QLineEdit, QComboBox, QCheckBox,
                                 QMessageBox, QWidget, QFrame, QScrollArea,
                                 QStackedWidget, QTextEdit, QSizePolicy)
    from PyQt5.QtCore import Qt, pyqtSignal
    from PyQt5.QtGui import QFont, QPainter, QPen, QBrush, QColor
    PYQT_AVAILABLE = True
except ImportError:
    PYQT_AVAILABLE = False
    print("PyQt5 not available - Home Assistant configuration dialog will not work")

class Plugin:
    def __init__(self):
        self.plugin_name = "Home Assistant Integration"
        self.name = "Home Assistant Integration"
        self.version = "1.0.0"
        self.settings_file = os.path.join(os.path.dirname(__file__), 'ha_settings.json')
        self.settings = self.load_settings()
        self.current_mode = None
        self.session_active = False
    
    def initialize(self) -> bool:
        """Initialize the plugin"""
        print(f"Initializing Home Assistant Integration plugin")
        print(f"Settings loaded: {bool(self.settings)}")
        
        # Test connection if configured
        if self.settings.get('ha_url') and self.settings.get('access_token'):
            success, message = self.test_connection()
            if success:
                print(f"Home Assistant connection successful: {message}")
            else:
                print(f"Home Assistant connection failed: {message}")
        else:
            print("Home Assistant not yet configured")
        
        return True
        
    def load_settings(self) -> Dict[str, Any]:
        """Load plugin settings from JSON file"""
        default_settings = {
            "ha_url": "http://homeassistant.local:8123",
            "access_token": "",
            "scenes": {
                "productivity": "scene.focus_productivity",
                "creativity": "scene.focus_creativity", 
                "social_media_detox": "scene.focus_detox",
                "default": "scene.focus_default"
            },
            "enabled": False,
            "timeout": 10,
            "verify_ssl": True
        }
        
        try:
            if os.path.exists(self.settings_file):
                with open(self.settings_file, 'r') as f:
                    loaded_settings = json.load(f)
                    # Merge with defaults to ensure all keys exist
                    default_settings.update(loaded_settings)
            return default_settings
        except Exception as e:
            print(f"Error loading Home Assistant settings: {e}")
            return default_settings
    
    def save_settings(self, settings: Dict[str, Any]):
        """Save plugin settings to JSON file"""
        try:
            with open(self.settings_file, 'w') as f:
                json.dump(settings, f, indent=2)
            self.settings = settings
            print("Home Assistant settings saved successfully")
        except Exception as e:
            print(f"Error saving Home Assistant settings: {e}")
    
    def test_connection(self) -> tuple[bool, str]:
        """Test connection to Home Assistant instance"""
        if not self.settings.get('access_token') or not self.settings.get('ha_url'):
            return False, "Missing Home Assistant URL or access token"
        
        try:
            headers = {
                'Authorization': f'Bearer {self.settings["access_token"]}',
                'Content-Type': 'application/json'
            }
            
            response = requests.get(
                f'{self.settings["ha_url"]}/api/',
                headers=headers,
                timeout=self.settings.get('timeout', 10),
                verify=self.settings.get('verify_ssl', True)
            )
            
            if response.status_code == 200:
                data = response.json()
                return True, f"Connected to Home Assistant {data.get('version', 'Unknown Version')}"
            else:
                return False, f"HTTP {response.status_code}: {response.text}"
                
        except requests.exceptions.RequestException as e:
            return False, f"Connection error: {str(e)}"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"
    
    def get_available_scenes(self) -> list[Dict[str, str]]:
        """Get list of available scenes from Home Assistant"""
        if not self.settings.get('access_token') or not self.settings.get('ha_url'):
            return []
        
        try:
            headers = {
                'Authorization': f'Bearer {self.settings["access_token"]}',
                'Content-Type': 'application/json'
            }
            
            response = requests.get(
                f'{self.settings["ha_url"]}/api/states',
                headers=headers,
                timeout=self.settings.get('timeout', 10),
                verify=self.settings.get('verify_ssl', True)
            )
            
            if response.status_code == 200:
                states = response.json()
                scenes = []
                for state in states:
                    if state['entity_id'].startswith('scene.'):
                        scenes.append({
                            'entity_id': state['entity_id'],
                            'name': state['attributes'].get('friendly_name', state['entity_id'])
                        })
                return sorted(scenes, key=lambda x: x['name'])
            else:
                print(f"Failed to get scenes: HTTP {response.status_code}")
                return []
                
        except Exception as e:
            print(f"Error getting Home Assistant scenes: {e}")
            return []
    
    def activate_scene(self, scene_entity_id: str) -> bool:
        """Activate a specific Home Assistant scene"""
        if not self.settings.get('enabled') or not scene_entity_id:
            return True  # Return True if disabled to avoid errors
            
        if not self.settings.get('access_token') or not self.settings.get('ha_url'):
            print("Home Assistant not configured")
            return False
        
        try:
            headers = {
                'Authorization': f'Bearer {self.settings["access_token"]}',
                'Content-Type': 'application/json'
            }
            
            # Call the scene.turn_on service
            data = {
                'entity_id': scene_entity_id
            }
            
            response = requests.post(
                f'{self.settings["ha_url"]}/api/services/scene/turn_on',
                headers=headers,
                json=data,
                timeout=self.settings.get('timeout', 10),
                verify=self.settings.get('verify_ssl', True)
            )
            
            if response.status_code in [200, 201]:
                print(f"Successfully activated Home Assistant scene: {scene_entity_id}")
                return True
            else:
                print(f"Failed to activate scene {scene_entity_id}: HTTP {response.status_code}")
                return False
                
        except Exception as e:
            print(f"Error activating Home Assistant scene {scene_entity_id}: {e}")
            return False
    
    # Plugin Lifecycle Hooks
    
    def on_session_start(self, session_data: Dict[str, Any]):
        """Called when a focus session starts"""
        if not self.settings.get('enabled'):
            return
            
        mode = session_data.get('mode', 'productivity')
        self.current_mode = mode
        self.session_active = True
        
        # Get the scene for this mode
        scene_entity_id = self.settings['scenes'].get(mode)
        if scene_entity_id:
            print(f"Home Assistant: Activating {mode} scene ({scene_entity_id})")
            success = self.activate_scene(scene_entity_id)
            if success:
                print(f"Home Assistant environment configured for {mode} mode")
            else:
                print(f"Failed to configure Home Assistant for {mode} mode")
        else:
            print(f"No Home Assistant scene configured for {mode} mode")
    
    def on_session_end(self, session_data: Dict[str, Any]):
        """Called when a focus session ends"""
        if not self.settings.get('enabled') or not self.session_active:
            return
            
        # Activate default scene
        default_scene = self.settings['scenes'].get('default')
        if default_scene:
            print("Home Assistant: Returning to default scene")
            success = self.activate_scene(default_scene)
            if success:
                print("Home Assistant environment restored to default")
            else:
                print("Failed to restore Home Assistant to default")
        
        self.current_mode = None
        self.session_active = False
    
    def on_goal_completed(self, goal: str, session_data: Dict[str, Any]):
        """Called when a goal is completed (optional enhancement)"""
        pass
    
    def on_session_summary_close(self, session_data: Dict[str, Any]):
        """Called when session summary is closed"""
        pass
    
    # Plugin Info
    
    def get_info(self) -> Dict[str, str]:
        """Return plugin information"""
        return {
            'name': self.plugin_name,
            'version': '1.0.0',
            'description': 'Integrates with Home Assistant to activate scenes/presets based on focus modes'
        }
    
    def is_enabled(self) -> bool:
        """Check if plugin is enabled"""
        return self.settings.get('enabled', False)
    
    def configure(self):
        """Open configuration dialog"""
        if not PYQT_AVAILABLE:
            print("PyQt5 not available - cannot open configuration dialog")
            return
        
        dialog = HomeAssistantConfigDialog(self)
        dialog.exec_()


class HomeAssistantConfigDialog(QDialog):
    """Apple-style configuration dialog for Home Assistant integration"""
    
    def __init__(self, plugin_instance, parent=None):
        super().__init__(parent)
        self.plugin = plugin_instance
        self.current_step = 0
        self.total_steps = 3  # Simplified to 3 steps
        self.init_ui()
        
    def init_ui(self):
        self.setWindowTitle('Home Assistant')
        self.setFixedSize(700, 700)  # Reasonable height
        
        # Apple-style background
        self.setStyleSheet("""
            QDialog {
                background-color: #f5f5f7;
                font-family: -apple-system, SF Pro Display, Helvetica Neue, sans-serif;
            }
        """)
        
        # Main layout with proper Apple spacing
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(40, 30, 40, 30)
        main_layout.setSpacing(20)
        
        # Header with Apple-style hierarchy
        self.create_header(main_layout)
        
        # Content area with clean container
        self.stacked_widget = QStackedWidget()
        self.stacked_widget.setStyleSheet("""
            QStackedWidget {
                background-color: white;
                border-radius: 12px;
                border: 1px solid #d1d1d6;
            }
        """)
        self.init_steps()
        main_layout.addWidget(self.stacked_widget, 1)
        
        # Navigation with Apple button styles
        self.create_navigation(main_layout)
    
    def create_header(self, layout):
        """Create Apple-style header"""
        header_container = QWidget()
        header_layout = QVBoxLayout(header_container)
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(8)
        
        # Main title
        title = QLabel('Home Assistant')
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 28px;
            font-weight: 700;
            color: #1d1d1f;
            letter-spacing: -0.5px;
        """)
        header_layout.addWidget(title)
        
        # Subtitle
        subtitle = QLabel('Smart home integration for focus sessions')
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setStyleSheet("""
            font-size: 15px;
            color: #86868b;
            font-weight: 400;
        """)
        header_layout.addWidget(subtitle)
        
        # Progress dots (Apple-style)
        self.progress_container = QWidget()
        self.create_progress_dots()
        header_layout.addWidget(self.progress_container)
        
        layout.addWidget(header_container)
    
    def create_progress_dots(self):
        """Create Apple-style progress dots"""
        dots_layout = QHBoxLayout(self.progress_container)
        dots_layout.setContentsMargins(0, 15, 0, 0)
        dots_layout.setSpacing(8)
        dots_layout.addStretch()
        
        self.progress_dots = []
        for i in range(self.total_steps):
            dot = QLabel('●')
            dot.setAlignment(Qt.AlignCenter)
            dot.setFixedSize(12, 12)
            if i == self.current_step:
                dot.setStyleSheet("color: #007aff; font-size: 16px;")
            else:
                dot.setStyleSheet("color: #d1d1d6; font-size: 12px;")
            self.progress_dots.append(dot)
            dots_layout.addWidget(dot)
        
        dots_layout.addStretch()
    
    def create_navigation(self, layout):
        """Create Apple-style navigation buttons"""
        nav_layout = QHBoxLayout()
        nav_layout.setContentsMargins(0, 10, 0, 0)
        
        # Back button
        self.back_btn = QPushButton('Back')
        self.back_btn.clicked.connect(self.previous_step)
        self.back_btn.setEnabled(False)
        self.back_btn.setFixedHeight(36)
        self.back_btn.setStyleSheet("""
            QPushButton {
                background-color: transparent;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                color: #1d1d1f;
                font-size: 14px;
                font-weight: 500;
                padding: 0 16px;
            }
            QPushButton:hover { background-color: #f5f5f7; }
            QPushButton:disabled { 
                color: #86868b; 
                border-color: #f0f0f0;
            }
        """)
        
        nav_layout.addWidget(self.back_btn)
        nav_layout.addStretch()
        
        # Continue/Finish button
        self.continue_btn = QPushButton('Continue')
        self.continue_btn.clicked.connect(self.next_step)
        self.continue_btn.setFixedHeight(36)
        self.continue_btn.setDefault(True)
        self.continue_btn.setStyleSheet("""
            QPushButton {
                background-color: #007aff;
                border: none;
                border-radius: 8px;
                color: white;
                font-size: 14px;
                font-weight: 600;
                padding: 0 20px;
            }
            QPushButton:hover { background-color: #0056cc; }
            QPushButton:pressed { background-color: #004499; }
        """)
        
        nav_layout.addWidget(self.continue_btn)
        layout.addLayout(nav_layout)
    
    def style_primary_button(self, button):
        """Style primary buttons to match main app"""
        button.setStyleSheet("""
            QPushButton {
                background-color: #007aff;
                color: white;
                border: none;
                padding: 12px 20px;
                border-radius: 8px;
                font-size: 14px;
                font-weight: 600;
            }
            QPushButton:hover {
                background-color: #0056cc;
            }
            QPushButton:pressed {
                background-color: #004499;
            }
        """)
    
    def style_secondary_button(self, button):
        """Style secondary buttons to match main app"""
        button.setStyleSheet("""
            QPushButton {
                background-color: white;
                border: 1px solid #d1d1d6;
                color: #1d1d1f;
                padding: 12px 20px;
                border-radius: 8px;
                font-size: 14px;
                font-weight: 500;
            }
            QPushButton:hover {
                background-color: #f5f5f7;
            }
            QPushButton:disabled {
                background-color: #f0f0f0;
                color: #999;
                border-color: #e0e0e0;
            }
        """)
    
    def style_input_field(self, field):
        """Style input fields to match main app"""
        field.setStyleSheet("""
            QLineEdit, QComboBox {
                background-color: white;
                border: 1px solid #d1d1d6;
                border-radius: 6px;
                padding: 10px 14px;
                font-size: 14px;
                color: #1d1d1f;
                min-height: 20px;
            }
            QLineEdit:focus, QComboBox:focus {
                border-color: #007aff;
            }
            QComboBox::drop-down {
                border: none;
                width: 20px;
            }
            QComboBox::down-arrow {
                image: none;
                border-left: 4px solid transparent;
                border-right: 4px solid transparent;
                border-top: 6px solid #666;
            }
        """)
    
    def create_step_container(self, content_widget):
        """Create container for step content"""
        container = QFrame()
        container.setStyleSheet("""
            QFrame {
                background-color: white;
                border: 1px solid #e0e0e0;
                border-radius: 8px;
                padding: 30px;
            }
        """)
        
        layout = QVBoxLayout(container)
        layout.setContentsMargins(30, 30, 30, 30)  # Increased margins
        layout.setSpacing(25)  # Increased spacing
        layout.addWidget(content_widget)
        
        return container
    
    def init_steps(self):
        """Initialize all setup steps"""
        # Step 1: Overview with visual flow
        self.stacked_widget.addWidget(self.create_overview_step())
        
        # Step 2: Connection setup
        self.stacked_widget.addWidget(self.create_connection_step())
        
        # Step 3: Scene configuration
        self.stacked_widget.addWidget(self.create_scenes_step())
    
    def create_overview_step(self):
        """Step 1: Visual overview of the integration"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(40, 30, 40, 30)
        layout.setSpacing(25)
        
        # Visual flow diagram with custom vector graphics
        flow_widget = self.create_flow_visual()
        layout.addWidget(flow_widget)
        
        # Simple explanation
        explanation = QLabel('Home Assistant scenes will automatically activate when you start focus sessions, creating the perfect environment for different types of work.')
        explanation.setWordWrap(True)
        explanation.setAlignment(Qt.AlignCenter)
        explanation.setStyleSheet("""
            font-size: 16px;
            color: #4a4a4a;
            line-height: 24px;
            padding: 0 20px;
        """)
        layout.addWidget(explanation)
        
        layout.addStretch()
        return widget
    
    def create_flow_visual(self):
        """Create Apple-style visual flow with custom graphics"""
        container = QWidget()
        container.setFixedHeight(200)
        layout = QHBoxLayout(container)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(30)
        
        # Focus session icon
        focus_icon = self.create_icon_widget("🎯", "Focus Session\nStarts", "#007aff")
        layout.addWidget(focus_icon)
        
        # Arrow
        arrow = QLabel("→")
        arrow.setAlignment(Qt.AlignCenter)
        arrow.setStyleSheet("font-size: 28px; color: #86868b; font-weight: 300;")
        layout.addWidget(arrow)
        
        # Home Assistant icon
        ha_icon = self.create_icon_widget("🏠", "Home Assistant\nScene Activates", "#ff9500")
        layout.addWidget(ha_icon)
        
        # Arrow
        arrow2 = QLabel("→")
        arrow2.setAlignment(Qt.AlignCenter)
        arrow2.setStyleSheet("font-size: 28px; color: #86868b; font-weight: 300;")
        layout.addWidget(arrow2)
        
        # Environment icon
        env_icon = self.create_icon_widget("✨", "Perfect\nEnvironment", "#34c759")
        layout.addWidget(env_icon)
        
        return container
    
    def create_icon_widget(self, emoji, text, color):
        """Create Apple-style icon widget with emoji and text"""
        widget = QWidget()
        widget.setFixedSize(120, 140)
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)
        
        # Icon background circle
        icon_container = QWidget()
        icon_container.setFixedSize(80, 80)
        icon_container.setStyleSheet(f"""
            background-color: {color};
            border-radius: 40px;
        """)
        
        # Emoji icon
        icon_layout = QVBoxLayout(icon_container)
        emoji_label = QLabel(emoji)
        emoji_label.setAlignment(Qt.AlignCenter)
        emoji_label.setStyleSheet("font-size: 32px;")
        icon_layout.addWidget(emoji_label)
        
        layout.addWidget(icon_container, 0, Qt.AlignCenter)
        
        # Text label
        text_label = QLabel(text)
        text_label.setAlignment(Qt.AlignCenter)
        text_label.setWordWrap(True)
        text_label.setStyleSheet("""
            font-size: 13px;
            font-weight: 500;
            color: #1d1d1f;
            line-height: 16px;
        """)
        layout.addWidget(text_label)
        
        return widget
    
    def create_connection_step(self):
        """Step 2: Simple connection form"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(40, 30, 40, 30)
        layout.setSpacing(20)
        
        # Form title
        title = QLabel('Connect to Home Assistant')
        title.setStyleSheet("""
            font-size: 20px;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 10px;
        """)
        layout.addWidget(title)
        
        # Form fields with Apple styling
        form_layout = QVBoxLayout()
        form_layout.setSpacing(35)  # More aggressive spacing
        
        # URL field section
        url_section = QVBoxLayout()
        url_section.setSpacing(12)  # More spacing within section
        
        url_label = QLabel('Home Assistant URL')
        url_label.setStyleSheet("font-size: 14px; color: #1d1d1f; font-weight: 500;")
        url_section.addWidget(url_label)
        
        self.url_input = QLineEdit()
        self.url_input.setPlaceholderText('http://homeassistant.local:8123')
        self.url_input.setText(self.plugin.settings.get('ha_url', ''))
        self.url_input.setFixedHeight(40)
        self.url_input.setStyleSheet("""
            QLineEdit {
                background-color: #f9f9f9;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                padding: 0 12px;
                font-size: 15px;
                color: #1d1d1f;
            }
            QLineEdit:focus {
                background-color: white;
                border-color: #007aff;
            }
        """)
        url_section.addWidget(self.url_input)
        form_layout.addLayout(url_section)
        
        # Token field section  
        token_section = QVBoxLayout()
        token_section.setSpacing(12)  # More spacing within section
        
        token_label = QLabel('Long-lived Access Token')
        token_label.setStyleSheet("font-size: 14px; color: #1d1d1f; font-weight: 500;")
        token_section.addWidget(token_label)
        
        self.token_input = QLineEdit()
        self.token_input.setPlaceholderText('Paste your Home Assistant token here')
        self.token_input.setText(self.plugin.settings.get('access_token', ''))
        self.token_input.setEchoMode(QLineEdit.Password)
        self.token_input.setFixedHeight(40)
        self.token_input.setStyleSheet("""
            QLineEdit {
                background-color: #f9f9f9;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                padding: 0 12px;
                font-size: 15px;
                color: #1d1d1f;
            }
            QLineEdit:focus {
                background-color: white;
                border-color: #007aff;
            }
        """)
        token_section.addWidget(self.token_input)
        
        # Help text right below the token input with proper container
        help_container = QWidget()
        help_container.setFixedHeight(50)  # Fixed height container
        help_layout = QVBoxLayout(help_container)
        help_layout.setContentsMargins(0, 8, 0, 8)
        
        help_text = QLabel('Create a token in Home Assistant → Profile → Long-lived access tokens')
        help_text.setStyleSheet("""
            font-size: 11px;
            color: #86868b;
            padding: 4px 0;
            background-color: transparent;
        """)
        help_text.setWordWrap(True)
        help_text.setAlignment(Qt.AlignTop)
        
        help_layout.addWidget(help_text)
        token_section.addWidget(help_container)
        form_layout.addLayout(token_section)
        
        # Test section with more spacing
        test_section = QVBoxLayout()
        test_section.setSpacing(18)  # Increased spacing in test section
        
        test_btn = QPushButton('Test Connection')
        test_btn.clicked.connect(self.test_connection)
        test_btn.setFixedHeight(36)
        test_btn.setStyleSheet("""
            QPushButton {
                background-color: #f9f9f9;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                color: #1d1d1f;
                font-size: 14px;
                font-weight: 500;
                padding: 0 16px;
            }
            QPushButton:hover { background-color: #f0f0f0; }
        """)
        test_section.addWidget(test_btn)
        
        # Status container with fixed height
        status_container = QWidget()
        status_container.setFixedHeight(60)  # Fixed height container
        status_layout = QVBoxLayout(status_container)
        status_layout.setContentsMargins(0, 10, 0, 10)
        
        self.connection_status = QLabel('Ready to test connection')
        self.connection_status.setStyleSheet("""
            font-size: 12px;
            color: #86868b;
            padding: 8px;
            background-color: transparent;
        """)
        self.connection_status.setWordWrap(True)
        self.connection_status.setAlignment(Qt.AlignTop)
        
        status_layout.addWidget(self.connection_status)
        test_section.addWidget(status_container)
        form_layout.addLayout(test_section)
        
        layout.addLayout(form_layout)
        layout.addStretch()
        
        return widget
    
    def create_scenes_step(self):
        """Step 3: Scene assignment with visual mode cards"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(40, 30, 40, 30)
        layout.setSpacing(20)
        
        # Title
        title = QLabel('Assign Scenes to Focus Modes')
        title.setStyleSheet("""
            font-size: 20px;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 10px;
        """)
        layout.addWidget(title)
        
        # Scene assignments with proper spacing
        scenes_layout = QVBoxLayout()
        scenes_layout.setSpacing(25)  # Reasonable spacing between scene assignments
        
        self.scene_combos = {}
        modes = [
            ('🎯 Productivity', 'productivity', '#007aff'),
            ('🎨 Creativity', 'creativity', '#ff9500'),
            ('🧘 Social Media Detox', 'social_media_detox', '#34c759'),
            ('🏠 Default', 'default', '#8e8e93')
        ]
        
        for display_name, mode_key, color in modes:
            mode_widget = self.create_mode_assignment_widget(display_name, mode_key, color)
            scenes_layout.addWidget(mode_widget)
        
        layout.addLayout(scenes_layout)
        
        # Add reasonable space before load button
        layout.addSpacing(40)
        
        # Load scenes button
        load_btn = QPushButton('Load Scenes from Home Assistant')
        load_btn.clicked.connect(self.load_scenes)
        load_btn.setFixedHeight(40)  # Taller button
        load_btn.setStyleSheet("""
            QPushButton {
                background-color: #f9f9f9;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                color: #007aff;
                font-size: 14px;
                font-weight: 500;
                padding: 0 16px;
            }
            QPushButton:hover { background-color: #f0f0f0; }
        """)
        layout.addWidget(load_btn)
        
        # Enable toggle with reasonable spacing
        enable_layout = QHBoxLayout()
        enable_layout.setContentsMargins(0, 30, 0, 0)  # Reasonable top margin
        self.enabled_checkbox = QCheckBox('Enable Home Assistant integration')
        self.enabled_checkbox.setChecked(self.plugin.settings.get('enabled', False))
        self.enabled_checkbox.setStyleSheet("""
            QCheckBox {
                font-size: 15px;
                font-weight: 500;
                color: #1d1d1f;
                spacing: 8px;
            }
            QCheckBox::indicator {
                width: 20px;
                height: 20px;
                border-radius: 4px;
                border: 2px solid #d1d1d6;
                background-color: white;
            }
            QCheckBox::indicator:checked {
                background-color: #007aff;
                border-color: #007aff;
                image: none;
            }
        """)
        enable_layout.addWidget(self.enabled_checkbox)
        enable_layout.addStretch()
        
        layout.addLayout(enable_layout)
        layout.addStretch()
        
        return widget
    
    def create_mode_assignment_widget(self, display_name, mode_key, color):
        """Create a mode assignment widget with visual styling"""
        container = QWidget()
        container.setFixedHeight(90)  # Even taller for maximum spacing
        layout = QHBoxLayout(container)
        layout.setContentsMargins(0, 20, 0, 20)  # Even larger vertical margins
        layout.setSpacing(25)  # More horizontal spacing
        
        # Mode label with colored indicator
        mode_label = QLabel(display_name)
        mode_label.setFixedWidth(200)
        mode_label.setStyleSheet(f"""
            font-size: 15px;
            font-weight: 500;
            color: {color};
            padding: 8px 12px;
            background-color: {color}15;
            border-radius: 8px;
        """)
        layout.addWidget(mode_label)
        
        # Scene selector
        combo = QComboBox()
        combo.setEditable(True)
        combo.setCurrentText(self.plugin.settings['scenes'].get(mode_key, ''))
        combo.setFixedHeight(50)  # Even taller combo box
        combo.setStyleSheet("""
            QComboBox {
                background-color: #f9f9f9;
                border: 1px solid #d1d1d6;
                border-radius: 6px;
                padding: 0 12px;
                font-size: 14px;
                color: #1d1d1f;
            }
            QComboBox:focus {
                background-color: white;
                border-color: #007aff;
            }
            QComboBox::drop-down {
                border: none;
                width: 20px;
            }
            QComboBox::down-arrow {
                width: 12px;
                height: 8px;
                background-image: none;
                border-left: 4px solid transparent;
                border-right: 4px solid transparent;
                border-top: 6px solid #86868b;
            }
        """)
        self.scene_combos[mode_key] = combo
        layout.addWidget(combo, 1)
        
        return container
    
    
    def next_step(self):
        """Navigate to next step or finish"""
        if self.current_step < self.total_steps - 1:
            self.current_step += 1
            self.update_step_ui()
        else:
            # Last step - save and close
            self.save_and_accept()
    
    def previous_step(self):
        """Navigate to previous step"""
        if self.current_step > 0:
            self.current_step -= 1
            self.update_step_ui()
    
    def update_step_ui(self):
        """Update UI for current step"""
        # Update progress dots
        for i, dot in enumerate(self.progress_dots):
            if i == self.current_step:
                dot.setStyleSheet("color: #007aff; font-size: 16px;")
            else:
                dot.setStyleSheet("color: #d1d1d6; font-size: 12px;")
        
        # Update stacked widget
        self.stacked_widget.setCurrentIndex(self.current_step)
        
        # Update navigation buttons
        self.back_btn.setEnabled(self.current_step > 0)
        
        if self.current_step == self.total_steps - 1:
            self.continue_btn.setText('Finish')
        else:
            self.continue_btn.setText('Continue')
    
    def test_connection(self):
        """Test Home Assistant connection"""
        temp_settings = self.plugin.settings.copy()
        temp_settings['ha_url'] = self.url_input.text().strip()
        temp_settings['access_token'] = self.token_input.text().strip()
        
        original_settings = self.plugin.settings
        self.plugin.settings = temp_settings
        
        try:
            success, message = self.plugin.test_connection()
            if success:
                self.connection_status.setText(f"✓ {message}")
                self.connection_status.setStyleSheet("color: #34c759; font-weight: 500;")
            else:
                self.connection_status.setText(f"✗ {message}")
                self.connection_status.setStyleSheet("color: #ff3b30; font-weight: 500;")
        finally:
            self.plugin.settings = original_settings
    
    def load_scenes(self):
        """Load available scenes from Home Assistant"""
        temp_settings = self.plugin.settings.copy()
        temp_settings['ha_url'] = self.url_input.text().strip()
        temp_settings['access_token'] = self.token_input.text().strip()
        
        original_settings = self.plugin.settings
        self.plugin.settings = temp_settings
        
        try:
            scenes = self.plugin.get_available_scenes()
            
            for combo in self.scene_combos.values():
                current_text = combo.currentText()
                combo.clear()
                combo.addItem("")  # Empty option
                
                for scene in scenes:
                    combo.addItem(f"{scene['name']}", scene['entity_id'])
                
                # Restore selection
                index = combo.findText(current_text)
                if index >= 0:
                    combo.setCurrentIndex(index)
            
            if scenes:
                QMessageBox.information(self, "Success", f"Loaded {len(scenes)} scenes from Home Assistant")
            else:
                QMessageBox.warning(self, "No Scenes", "No scenes found. Please create scenes in Home Assistant first.")
                
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to load scenes: {str(e)}")
        finally:
            self.plugin.settings = original_settings
    
    def save_and_accept(self):
        """Save settings and close dialog"""
        settings = {
            'ha_url': self.url_input.text().strip(),
            'access_token': self.token_input.text().strip(),
            'enabled': self.enabled_checkbox.isChecked(),
            'scenes': {
                'productivity': self.scene_combos['productivity'].currentData() or self.scene_combos['productivity'].currentText(),
                'creativity': self.scene_combos['creativity'].currentData() or self.scene_combos['creativity'].currentText(),
                'social_media_detox': self.scene_combos['social_media_detox'].currentData() or self.scene_combos['social_media_detox'].currentText(),
                'default': self.scene_combos['default'].currentData() or self.scene_combos['default'].currentText()
            },
            'timeout': 10,
            'verify_ssl': True
        }
        
        self.plugin.save_settings(settings)
        self.accept()
    
    def load_scenes(self):
        """Load available scenes from Home Assistant for step 3"""
        if self.current_step != 2:  # Only available on scenes step
            return
            
        temp_settings = self.plugin.settings.copy()
        temp_settings['ha_url'] = self.url_input.text().strip()
        temp_settings['access_token'] = self.token_input.text().strip()
        
        original_settings = self.plugin.settings
        self.plugin.settings = temp_settings
        
        try:
            scenes = self.plugin.get_available_scenes()
            
            for combo in self.scene_combos.values():
                current_text = combo.currentText()
                combo.clear()
                combo.addItem("Select a scene...", "")
                
                for scene in scenes:
                    combo.addItem(f"{scene['name']}", scene['entity_id'])
                
                # Restore selection if it exists
                index = combo.findText(current_text)
                if index >= 0:
                    combo.setCurrentIndex(index)
            
            if scenes:
                QMessageBox.information(self, "Scenes Loaded", f"Found {len(scenes)} scenes in Home Assistant")
            else:
                QMessageBox.warning(self, "No Scenes Found", "No scenes found in Home Assistant. Please create some scenes first.")
                
        except Exception as e:
            QMessageBox.critical(self, "Connection Error", f"Failed to load scenes: {str(e)}")
        finally:
            self.plugin.settings = original_settings


def create_plugin():
    """Factory function to create plugin instance"""
    return Plugin()