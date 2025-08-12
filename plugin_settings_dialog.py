#!/usr/bin/env python3

from PyQt5.QtWidgets import (QMainWindow, QVBoxLayout, QHBoxLayout, QLabel, 
                             QPushButton, QCheckBox, QScrollArea, QWidget, QFrame, QSpinBox,
                             QMessageBox, QProgressDialog, QApplication)
from PyQt5.QtCore import Qt, QTimer
from plugin_system import plugin_manager
from ai_service import ai_service
import json
import os

class PluginSettingsDialog(QMainWindow):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Focus Utility - Settings')
        self.setFixedSize(700, 650)
        
        # Normal window behavior for configuration dialogs
        self.setWindowFlags(Qt.Window)
        
        # Set window to come to front initially but not stay on top
        self.setAttribute(Qt.WA_ShowWithoutActivating, False)  # Allow activation
        
        # Create central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        self.setStyleSheet("""
            QMainWindow {
                background-color: #f0f0f0;
            }
            QWidget {
                background-color: #f0f0f0;
                font-family: Helvetica, Arial;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)
        
        # Title
        title = QLabel("Plugins & Settings")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        layout.addWidget(title)
        
        # Subtitle
        subtitle = QLabel("Enable or disable plugins and customize your focus experience")
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setWordWrap(True)
        subtitle.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
        """)
        layout.addWidget(subtitle)
        
        # App Settings Section (compact, no frame)
        app_settings_layout = QVBoxLayout()
        app_settings_layout.setSpacing(10)
        app_settings_layout.setContentsMargins(0, 0, 0, 0)
        
        # Popup interval setting
        popup_row = QHBoxLayout()
        interval_label = QLabel("How often should we check in?:")
        interval_label.setStyleSheet("""
            font-size: 14px;
            color: #1d1d1f;
        """)
        
        self.popup_interval_spinbox = QSpinBox()
        self.popup_interval_spinbox.setMinimum(1) 
        self.popup_interval_spinbox.setMaximum(60)
        self.popup_interval_spinbox.setSuffix(" minutes")
        self.popup_interval_spinbox.setValue(self.get_popup_interval_setting())
        
        spinbox_style = """
            QSpinBox {
                padding: 6px 8px;
                font-size: 14px;
                border: 1px solid #d1d1d6;
                border-radius: 6px;
                background-color: white;
                color: #1d1d1f;
                min-width: 120px;
            }
            QSpinBox::up-button {
                subcontrol-origin: border;
                subcontrol-position: top right;
                width: 20px;
                border-left: 1px solid #d1d1d6;
                border-bottom: 1px solid #d1d1d6;
                border-top-right-radius: 6px;
                background-color: #f8f8f8;
            }
            QSpinBox::up-button:hover {
                background-color: #e8e8e8;
            }
            QSpinBox::up-button:pressed {
                background-color: #d8d8d8;
            }
            QSpinBox::up-arrow {
                image: none;
                width: 0;
                height: 0;
                border-left: 4px solid transparent;
                border-right: 4px solid transparent;
                border-bottom: 6px solid #666;
                margin-bottom: 2px;
            }
            QSpinBox::down-button {
                subcontrol-origin: border;
                subcontrol-position: bottom right;
                width: 20px;
                border-left: 1px solid #d1d1d6;
                border-top: 1px solid #d1d1d6;
                border-bottom-right-radius: 6px;
                background-color: #f8f8f8;
            }
            QSpinBox::down-button:hover {
                background-color: #e8e8e8;
            }
            QSpinBox::down-button:pressed {
                background-color: #d8d8d8;
            }
            QSpinBox::down-arrow {
                image: none;
                width: 0;
                height: 0;
                border-left: 4px solid transparent;
                border-right: 4px solid transparent;
                border-top: 6px solid #666;
                margin-top: 2px;
            }
        """
        
        self.popup_interval_spinbox.setStyleSheet(spinbox_style)
        
        popup_row.addWidget(interval_label)
        popup_row.addStretch()
        popup_row.addWidget(self.popup_interval_spinbox)
        
        # Breath duration setting
        breath_row = QHBoxLayout()
        breath_label = QLabel("Breath screen duration:")
        breath_label.setStyleSheet("""
            font-size: 14px;
            color: #1d1d1f;
        """)
        
        self.breath_duration_spinbox = QSpinBox()
        self.breath_duration_spinbox.setMinimum(5)
        self.breath_duration_spinbox.setMaximum(60)
        self.breath_duration_spinbox.setSuffix(" seconds")
        self.breath_duration_spinbox.setValue(self.get_breath_duration_setting())
        self.breath_duration_spinbox.setStyleSheet(spinbox_style)
        
        breath_row.addWidget(breath_label)
        breath_row.addStretch()
        breath_row.addWidget(self.breath_duration_spinbox)
        
        app_settings_layout.addLayout(popup_row)
        app_settings_layout.addLayout(breath_row)
        
        layout.addLayout(app_settings_layout)
        
        # AI Settings Section
        ai_settings_layout = QVBoxLayout()
        ai_settings_layout.setSpacing(10)
        ai_settings_layout.setContentsMargins(0, 10, 0, 10)
        
        # Detect Programs button
        detect_button = QPushButton("Detect Programs")
        detect_button.setStyleSheet("""
            QPushButton {
                background-color: #007AFF;
                color: white;
                border: none;
                border-radius: 8px;
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 500;
                min-height: 20px;
            }
            QPushButton:hover {
                background-color: #0056CC;
            }
            QPushButton:pressed {
                background-color: #004499;
            }
            QPushButton:disabled {
                background-color: #cccccc;
                color: #666666;
            }
        """)
        detect_button.clicked.connect(self.detect_programs)
        
        detect_label = QLabel("Use AI to analyze your installed apps and websites, automatically configuring focus modes for optimal productivity")
        detect_label.setStyleSheet("""
            font-size: 12px;
            color: #666666;
            margin-top: 5px;
        """)
        detect_label.setWordWrap(True)
        
        ai_settings_layout.addWidget(detect_button)
        ai_settings_layout.addWidget(detect_label)
        layout.addLayout(ai_settings_layout)
        
        # Plugins scroll area
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setMinimumHeight(400)  # Make plugins section taller
        scroll.setStyleSheet("""
            QScrollArea {
                border: 1px solid #e0e0e0;
                border-radius: 8px;
                background-color: #fafafa;
            }
            QScrollBar:vertical {
                border: none;
                background-color: #f0f0f0;
                width: 12px;
                border-radius: 6px;
                margin: 0;
            }
            QScrollBar::handle:vertical {
                background-color: #c0c0c0;
                border-radius: 6px;
                min-height: 20px;
                margin: 2px;
            }
            QScrollBar::handle:vertical:hover {
                background-color: #a0a0a0;
            }
            QScrollBar::handle:vertical:pressed {
                background-color: #808080;
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0px;
                subcontrol-position: top;
                subcontrol-origin: margin;
            }
            QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
                background: none;
            }
        """)
        
        plugins_widget = QWidget()
        self.plugins_layout = QVBoxLayout(plugins_widget)
        self.plugins_layout.setSpacing(12)
        self.plugins_layout.setContentsMargins(15, 15, 15, 15)
        
        # Load plugins
        self.plugin_checkboxes = {}
        self.load_plugins()
        
        scroll.setWidget(plugins_widget)
        layout.addWidget(scroll)
        
        # Buttons
        button_layout = QHBoxLayout()
        
        cancel_btn = QPushButton("Close")
        cancel_btn.clicked.connect(self.close)
        cancel_btn.setStyleSheet("""
            QPushButton {
                padding: 12px 20px;
                font-size: 14px;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: white;
                color: #1d1d1f;
            }
            QPushButton:hover { background-color: #f5f5f7; }
        """)
        
        save_btn = QPushButton("Save & Close")
        save_btn.clicked.connect(self.save_and_close)
        save_btn.setDefault(True)
        save_btn.setStyleSheet("""
            QPushButton {
                padding: 12px 20px;
                font-size: 14px;
                font-weight: 600;
                border: none;
                border-radius: 8px;
                background-color: #007aff;
                color: white;
            }
            QPushButton:hover { background-color: #0056cc; }
        """)
        
        button_layout.addStretch()
        button_layout.addWidget(cancel_btn)
        button_layout.addWidget(save_btn)
        
        layout.addLayout(button_layout)
        central_widget.setLayout(layout)
    
    def save_and_close(self):
        """Save plugin changes and close window"""
        self.save_changes()
        self.close()
    
    def load_plugins(self):
        """Load all available plugins into the UI"""
        available_plugins = plugin_manager.get_available_plugins()
        
        if not available_plugins:
            # Show no plugins message
            no_plugins_label = QLabel("No plugins found in the plugins directory")
            no_plugins_label.setAlignment(Qt.AlignCenter)
            no_plugins_label.setStyleSheet("""
                font-size: 14px;
                color: #86868b;
                padding: 20px;
            """)
            self.plugins_layout.addWidget(no_plugins_label)
            return
        
        for plugin_id, manifest in available_plugins.items():
            # Create plugin card
            plugin_frame = QFrame()
            plugin_frame.setStyleSheet("""
                QFrame {
                    background-color: white;
                    border: 1px solid #e0e0e0;
                    border-radius: 8px;
                    padding: 12px;
                }
            """)
            
            plugin_layout = QVBoxLayout(plugin_frame)
            plugin_layout.setSpacing(8)
            plugin_layout.setContentsMargins(12, 12, 12, 12)
            
            # Plugin header with checkbox and name
            header_layout = QHBoxLayout()
            
            checkbox = QCheckBox()
            checkbox.setChecked(plugin_manager.is_plugin_enabled(plugin_id))
            checkbox.setStyleSheet("""
                QCheckBox::indicator {
                    width: 18px;
                    height: 18px;
                    border-radius: 9px;
                    border: 2px solid #d1d1d6;
                    background-color: white;
                }
                QCheckBox::indicator:checked {
                    background-color: #007aff;
                    border-color: #007aff;
                }
            """)
            
            plugin_name = QLabel(manifest['name'])
            plugin_name.setStyleSheet("""
                font-size: 16px;
                font-weight: 600;
                color: #1d1d1f;
            """)
            
            version_label = QLabel(f"v{manifest['version']}")
            version_label.setStyleSheet("""
                font-size: 12px;
                color: #86868b;
                background-color: #f0f0f0;
                padding: 2px 8px;
                border-radius: 4px;
            """)
            
            header_layout.addWidget(checkbox)
            header_layout.addWidget(plugin_name)
            header_layout.addWidget(version_label)
            header_layout.addStretch()
            
            # Add configure button for email plugin
            if plugin_id == 'email_assistant':
                config_btn = QPushButton("Configure Email")
                config_btn.clicked.connect(lambda: self.configure_email_plugin(plugin_id))
                config_btn.setStyleSheet("""
                    QPushButton {
                        padding: 6px 12px;
                        font-size: 12px;
                        font-weight: 500;
                        border: 1px solid #007aff;
                        border-radius: 6px;
                        background-color: white;
                        color: #007aff;
                    }
                    QPushButton:hover { background-color: #f0f8ff; }
                """)
                header_layout.addWidget(config_btn)
            
            plugin_layout.addLayout(header_layout)
            
            # Plugin description
            description = QLabel(manifest['description'])
            description.setWordWrap(True)
            description.setStyleSheet("""
                font-size: 13px;
                color: #4a4a4a;
                line-height: 1.4;
            """)
            plugin_layout.addWidget(description)
            
            # Add status for email plugin
            if plugin_id == 'email_assistant':
                status_text = self.get_email_plugin_status(plugin_id)
                status_label = QLabel(status_text)
                status_label.setStyleSheet("""
                    font-size: 12px;
                    color: #86868b;
                    font-style: italic;
                    margin-top: 4px;
                """)
                plugin_layout.addWidget(status_label)
            
            self.plugins_layout.addWidget(plugin_frame)
            self.plugin_checkboxes[plugin_id] = checkbox
    
    def get_email_plugin_status(self, plugin_id):
        """Get status text for email plugin configuration"""
        if plugin_id == 'email_assistant':
            try:
                # Check if plugin is loaded and has configuration
                if plugin_id in plugin_manager.loaded_plugins:
                    plugin_instance = plugin_manager.loaded_plugins[plugin_id]
                    if hasattr(plugin_instance, 'email_config') and plugin_instance.email_config:
                        email = plugin_instance.email_config.get('email', 'unknown')
                        provider = plugin_instance.email_config.get('provider', 'Unknown')
                        return f"Configured: {provider} account ({email})"
                    else:
                        return "Email not configured - click 'Configure Email' to set up"
                else:
                    return "Plugin not loaded - enable first, then configure"
            except Exception:
                return "Error checking configuration status"
        return ""
    
    def configure_email_plugin(self, plugin_id):
        """Configure the email plugin"""
        if plugin_id == 'email_assistant':
            # Enable plugin first if not enabled
            if not plugin_manager.is_plugin_enabled(plugin_id):
                plugin_manager.enable_plugin(plugin_id)
                # Update checkbox state
                if plugin_id in self.plugin_checkboxes:
                    self.plugin_checkboxes[plugin_id].setChecked(True)
            
            # Get the plugin instance and call its configure method
            if plugin_id in plugin_manager.loaded_plugins:
                plugin_instance = plugin_manager.loaded_plugins[plugin_id]
                plugin_instance.configure_email()
    
    def save_changes(self):
        """Save plugin enable/disable changes and app settings"""
        for plugin_id, checkbox in self.plugin_checkboxes.items():
            if checkbox.isChecked():
                if not plugin_manager.is_plugin_enabled(plugin_id):
                    plugin_manager.enable_plugin(plugin_id)
            else:
                if plugin_manager.is_plugin_enabled(plugin_id):
                    plugin_manager.disable_plugin(plugin_id)
        
        # Save app settings
        self.save_popup_interval_setting(self.popup_interval_spinbox.value())
        self.save_breath_duration_setting(self.breath_duration_spinbox.value())
    
    def get_popup_interval_setting(self):
        """Get the popup interval setting from JSON file"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            settings_file = os.path.join(script_dir, 'plugin_settings.json')
            
            if os.path.exists(settings_file):
                with open(settings_file, 'r') as f:
                    settings = json.load(f)
                return settings.get('app_settings', {}).get('popup_interval_minutes', 1)
            return 1
        except Exception:
            return 1
    
    def get_breath_duration_setting(self):
        """Get breath screen duration setting from config, default to 15 seconds"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            settings_file = os.path.join(script_dir, 'plugin_settings.json')
            
            if os.path.exists(settings_file):
                with open(settings_file, 'r') as f:
                    settings = json.load(f)
                return settings.get('app_settings', {}).get('breath_duration_seconds', 15)
            return 15
        except Exception:
            return 15
    
    def save_popup_interval_setting(self, interval_minutes):
        """Save the popup interval setting to JSON file"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            settings_file = os.path.join(script_dir, 'plugin_settings.json')
            
            # Load existing settings
            settings = {}
            if os.path.exists(settings_file):
                with open(settings_file, 'r') as f:
                    settings = json.load(f)
            
            # Update app settings
            if 'app_settings' not in settings:
                settings['app_settings'] = {}
            settings['app_settings']['popup_interval_minutes'] = interval_minutes
            
            # Save back to file
            with open(settings_file, 'w') as f:
                json.dump(settings, f, indent=2)
                
        except Exception as e:
            print(f"Error saving popup interval setting: {e}")
    
    def save_breath_duration_setting(self, duration_seconds):
        """Save the breath duration setting to JSON file"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            settings_file = os.path.join(script_dir, 'plugin_settings.json')
            
            # Load existing settings
            settings = {}
            if os.path.exists(settings_file):
                with open(settings_file, 'r') as f:
                    settings = json.load(f)
            
            # Update app settings
            if 'app_settings' not in settings:
                settings['app_settings'] = {}
            settings['app_settings']['breath_duration_seconds'] = duration_seconds
            
            # Save back to file
            with open(settings_file, 'w') as f:
                json.dump(settings, f, indent=2)
                
        except Exception as e:
            print(f"Error saving breath duration setting: {e}")
    
    def showEvent(self, event):
        """Override showEvent to bring window to front when first shown"""
        super().showEvent(event)
        
        # Bring window to front but don't keep it on top
        self.raise_()
    
    def detect_programs(self):
        """Use AI to detect and categorize programs for focus modes"""
        if not ai_service.is_available():
            QMessageBox.warning(self, "AI Service Unavailable", 
                              "AI service is not available. Please ensure your Groq API key is configured in groq_api_key.txt")
            return
        
        # Show confirmation dialog
        reply = QMessageBox.question(self, "Detect Programs", 
                                   "This will analyze your installed applications and websites, then automatically update your focus mode configurations.\n\n"
                                   "This may take a few minutes and will overwrite existing mode configurations.\n\n"
                                   "Continue?",
                                   QMessageBox.Yes | QMessageBox.No,
                                   QMessageBox.No)
        
        if reply != QMessageBox.Yes:
            return
        
        # Show progress dialog
        progress = QProgressDialog("Analyzing programs and generating focus modes...", "Cancel", 0, 100, self)
        progress.setWindowTitle("AI Program Detection")
        progress.setMinimumDuration(0)
        progress.setValue(10)
        
        QApplication.processEvents()
        
        try:
            # Get installed applications
            print("Getting installed applications...")
            apps = ai_service.get_installed_applications()
            progress.setValue(30)
            QApplication.processEvents()
            
            if progress.wasCanceled():
                return
            
            # Categorize apps
            print("Categorizing applications with AI...")
            app_categories = ai_service.categorize_apps_for_modes(apps)
            progress.setValue(60)
            QApplication.processEvents()
            
            if progress.wasCanceled():
                return
            
            # Generate website blocks
            print("Generating website blocks...")
            site_categories = ai_service.generate_website_blocks_for_modes()
            progress.setValue(80)
            QApplication.processEvents()
            
            if progress.wasCanceled():
                return
            
            # Update mode files
            print("Updating focus mode configurations...")
            self._update_mode_files(app_categories, site_categories)
            progress.setValue(100)
            QApplication.processEvents()
            
            progress.close()
            
            # Show completion message
            total_apps = sum(len(apps) for apps in app_categories.values())
            total_sites = sum(len(sites) for sites in site_categories.values())
            
            QMessageBox.information(self, "Detection Complete", 
                                  f"Successfully analyzed and configured focus modes!\n\n"
                                  f"{len(apps)} applications analyzed\n"
                                  f"{total_apps} app assignments made\n"
                                  f"{total_sites} website blocks configured\n\n"
                                  f"Your focus modes have been optimized for your system.")
                                  
        except Exception as e:
            progress.close()
            print(f"Error during program detection: {e}")
            QMessageBox.critical(self, "Detection Error", 
                               f"An error occurred during program detection:\n\n{str(e)}")
    
    def _update_mode_files(self, app_categories: dict, site_categories: dict):
        """Update the mode and host files with AI-generated content"""
        script_dir = os.path.dirname(os.path.abspath(__file__))
        
        # Update apps for each mode
        for mode, apps in app_categories.items():
            mode_file = os.path.join(script_dir, 'modes', f'{mode}.txt')
            
            # Backup existing file
            if os.path.exists(mode_file):
                backup_file = f'{mode_file}.backup'
                try:
                    import shutil
                    shutil.copy2(mode_file, backup_file)
                    print(f"Backed up existing {mode}.txt")
                except:
                    pass
            
            # Write new content
            with open(mode_file, 'w') as f:
                f.write('\n'.join(sorted(apps)))
            print(f"Updated {mode}.txt with {len(apps)} apps")
        
        # Update hosts for each mode
        for mode, sites in site_categories.items():
            hosts_file = os.path.join(script_dir, 'hosts', f'{mode}_hosts')
            
            # Backup existing file
            if os.path.exists(hosts_file):
                backup_file = f'{hosts_file}.backup'
                try:
                    import shutil
                    shutil.copy2(hosts_file, backup_file)
                    print(f"Backed up existing {mode}_hosts")
                except:
                    pass
            
            # Write new content with comprehensive blocking
            with open(hosts_file, 'w') as f:
                for site in sorted(sites):
                    # Remove any protocol or path if included
                    clean_site = site.replace('https://', '').replace('http://', '').split('/')[0]
                    
                    # Block the main domain and common subdomains
                    f.write(f'127.0.0.1 {clean_site}\n')
                    f.write(f'127.0.0.1 www.{clean_site}\n')
                    f.write(f'127.0.0.1 m.{clean_site}\n')
                    f.write(f'127.0.0.1 mobile.{clean_site}\n')
                    f.write(f'127.0.0.1 touch.{clean_site}\n')
                    f.write(f'127.0.0.1 app.{clean_site}\n')
                    f.write(f'127.0.0.1 apps.{clean_site}\n')
                    f.write(f'127.0.0.1 api.{clean_site}\n')
                    f.write(f'127.0.0.1 cdn.{clean_site}\n')
                    f.write(f'127.0.0.1 static.{clean_site}\n')
                    f.write(f'127.0.0.1 assets.{clean_site}\n')
                    
                    # For social media sites, add specific common subdomains
                    if any(social in clean_site for social in ['facebook', 'instagram', 'twitter', 'tiktok']):
                        f.write(f'127.0.0.1 graph.{clean_site}\n')
                        f.write(f'127.0.0.1 connect.{clean_site}\n')
                        f.write(f'127.0.0.1 login.{clean_site}\n')
                        f.write(f'127.0.0.1 auth.{clean_site}\n')
                    
                    # For YouTube, block additional Google domains
                    if 'youtube' in clean_site:
                        f.write('127.0.0.1 youtubei.googleapis.com\n')
                        f.write('127.0.0.1 youtube-ui.l.google.com\n')
                        f.write('127.0.0.1 youtu.be\n')
                        f.write('127.0.0.1 www.youtu.be\n')
            
            # Count total entries for more accurate reporting
            total_entries = len(sites) * 11  # Base entries per site
            social_sites = sum(1 for site in sites if any(social in site for social in ['facebook', 'instagram', 'twitter', 'tiktok']))
            youtube_sites = sum(1 for site in sites if 'youtube' in site)
            total_entries += social_sites * 4  # Additional social media entries
            total_entries += youtube_sites * 4  # Additional YouTube entries
            
            print(f"Updated {mode}_hosts with {len(sites)} base sites ({total_entries} total blocked URLs)")
        self.activateWindow()
        
        # Ensure it's properly focused
        self.setFocus()
        