#!/usr/bin/env python3

import sys
import os
import subprocess
import time
import signal
import atexit
import copy
from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QComboBox, QPushButton, QFrame, QLineEdit, QDialog, QGraphicsDropShadowEffect,
                             QSpinBox, QTextEdit, QCheckBox, QScrollArea, QProgressBar, QGraphicsBlurEffect,
                             QSystemTrayIcon, QMenu, QAction)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QPropertyAnimation, QEasingCurve, QThread, QUrl, QObject, QRect
from PyQt5.QtGui import QFont, QPalette, QColor, QPainter, QPen, QBrush, QPixmap, QRadialGradient, QIcon, QPainterPath
try:
    from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent
    from PyQt5.QtMultimediaWidgets import QVideoWidget
    VIDEO_SUPPORT = True
except ImportError:
    print("Warning: PyQt5 multimedia not available. Video transitions will be skipped.")
    VIDEO_SUPPORT = False
import math
import json
import time as time_module
from datetime import datetime, timedelta
from typing import List

def get_app_icon():
    """Get the application icon for dock/window display"""
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        icon_path = os.path.join(script_dir, 'icon.png')
        
        if os.path.exists(icon_path):
            icon = QIcon(icon_path)
            # Verify the icon loaded successfully
            if not icon.isNull():
                return icon
        
        # Create a simple fallback icon
        icon_pixmap = QPixmap(32, 32)
        icon_pixmap.fill(Qt.transparent)
        
        painter = QPainter(icon_pixmap)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Draw blue circle
        painter.setBrush(QBrush(QColor(0, 122, 255)))
        painter.setPen(Qt.NoPen)
        painter.drawEllipse(4, 4, 24, 24)
        
        # Draw white "F" in center
        painter.setPen(Qt.white)
        painter.setFont(QFont("Arial", 16, QFont.Bold))
        painter.drawText(icon_pixmap.rect(), Qt.AlignCenter, "F")
        painter.end()
        
        return QIcon(icon_pixmap)
    
    except Exception as e:
        print(f"Warning: Could not load app icon: {e}")
        # Return empty icon if everything fails
        return QIcon()

def get_popup_interval_setting():
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

def get_breath_duration_setting():
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

def stop_focus_mode_with_password():
    """Stop focus mode, asking for password if needed"""
    try:
        import subprocess
        
        # Initialize password variable
        password = None
        
        # Try to determine if we need website blocking cleanup (sudo required)
        needs_sudo = False
        try:
            # Check if we modified hosts file (if current_mode file exists)
            script_dir = os.path.dirname(os.path.abspath(__file__))
            current_mode_file = os.path.join(script_dir, 'current_mode')
            if os.path.exists(current_mode_file) and os.path.getsize(current_mode_file) > 0:
                needs_sudo = True
        except:
            pass
        
        if needs_sudo:
            # Get password for website blocking cleanup (using stored password if available)
            try:
                from password_manager import get_sudo_password
                password = get_sudo_password()
            except ImportError:
                # Fallback to original method if password manager not available
                from PyQt5.QtWidgets import QDialog
                password_dialog = PasswordDialog()
                password_dialog.setWindowTitle('Cleanup Required')
                if password_dialog.exec_() == QDialog.Accepted:
                    password = password_dialog.password
                else:
                    password = None
            
            if password:
                
                # Run cleanup commands with password
                script_dir = os.path.dirname(os.path.abspath(__file__))
                
                # Kill processes first (no sudo needed)
                subprocess.run(['pkill', '-f', 'kill_looper'], cwd=script_dir, timeout=5)
                subprocess.run(['pkill', '-f', 'monitor_active'], cwd=script_dir, timeout=5)
                
                # Reset hosts file with password
                try:
                    hosts_reset = f'echo "{password}" | sudo -S bash -c \'cat > /etc/hosts <<EOF\n127.0.0.1 localhost\n::1 localhost\nEOF\''
                    subprocess.run(hosts_reset, shell=True, cwd=script_dir, timeout=10)
                    
                    # Flush DNS
                    dns_flush = f'echo "{password}" | sudo -S dscacheutil -flushcache'
                    subprocess.run(dns_flush, shell=True, cwd=script_dir, timeout=5)
                except:
                    pass
            else:
                print("Password required for complete cleanup - skipping sudo commands")
        
        # Run cleanup with password if we have one
        script_dir = os.path.dirname(os.path.abspath(__file__))
        if password:
            # Run cleanup commands with password directly
            try:
                # Kill processes first (no sudo needed)
                subprocess.run(['pkill', '-f', 'kill_looper'], check=False, timeout=5)
                subprocess.run(['pkill', '-f', 'kill_disallowed'], check=False, timeout=5) 
                subprocess.run(['pkill', '-f', 'monitor_active'], check=False, timeout=5)
                subprocess.run(['pkill', '-9', '-f', 'kill_looper'], check=False, timeout=3)
                subprocess.run(['pkill', '-9', '-f', 'kill_disallowed'], check=False, timeout=3)
                subprocess.run(['pkill', '-9', '-f', 'monitor_active'], check=False, timeout=3)
                
                # Clear current mode
                current_mode_file = os.path.join(script_dir, 'current_mode')
                try:
                    with open(current_mode_file, 'w') as f:
                        f.write('')
                except:
                    pass
                
                # Reset hosts file with password
                hosts_reset = f'echo "{password}" | sudo -S bash -c \'cat > /etc/hosts <<EOF\n127.0.0.1 localhost\n::1 localhost\nEOF\''
                subprocess.run(hosts_reset, shell=True, timeout=10)
                
                # Flush DNS cache with password
                subprocess.run(f'echo "{password}" | sudo -S dscacheutil -flushcache', shell=True, timeout=5)
                subprocess.run(f'echo "{password}" | sudo -S killall -HUP mDNSResponder', shell=True, timeout=5)
                
                print("✅ Focus mode cleanup completed successfully with password")
                
            except subprocess.TimeoutExpired:
                print("⚠️  Some cleanup commands timed out but continuing...")
            except Exception as e:
                print(f"Error during password-based cleanup: {e}")
        else:
            # Fallback to script without sudo commands
            try:
                # Create a non-sudo version of cleanup
                cleanup_script = '''#!/bin/bash
echo "Stopping Focus Mode (no sudo)..."
> current_mode
pkill -f "kill_looper.sh" 2>/dev/null
pkill -f "kill_disallowed.sh" 2>/dev/null  
pkill -f "monitor_active_programs.sh" 2>/dev/null
sleep 1
pkill -9 -f "kill_looper" 2>/dev/null
pkill -9 -f "kill_disallowed" 2>/dev/null
pkill -9 -f "monitor_active" 2>/dev/null
echo "✅ Basic cleanup completed (hosts file not reset)"
'''
                
                with open(os.path.join(script_dir, 'cleanup_no_sudo.sh'), 'w') as f:
                    f.write(cleanup_script)
                os.chmod(os.path.join(script_dir, 'cleanup_no_sudo.sh'), 0o755)
                
                subprocess.run(['bash', './cleanup_no_sudo.sh'], 
                              cwd=script_dir, 
                              timeout=10)
            except Exception as e:
                print(f"Error during basic cleanup: {e}")
        
    except Exception as e:
        print(f"Error during focus mode cleanup: {e}")
        # Continue anyway - don't let cleanup failures prevent app exit

class TimePickerDialog(QDialog):
    def __init__(self, parent=None, mode=None):
        super().__init__(parent)
        self.duration_minutes = 0
        self.mode = mode or "Focus"
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Session Duration')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(400, 250)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        self.setAttribute(Qt.WA_ShowWithoutActivating, False)  # Allow activation
        
        # Add shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 80))
        shadow.setOffset(0, 10)
        self.setGraphicsEffect(shadow)
        
        self.center_window()
        
        self.setStyleSheet("""
            QDialog {
                background-color: white;
                border-radius: 20px;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)
        
        # Title
        title = QLabel("How long is your focus session?")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        layout.addWidget(title)
        
        # Mode label
        mode_label = QLabel(f"Current Focus Mode: {self.mode.title()}")
        mode_label.setAlignment(Qt.AlignCenter)
        mode_label.setStyleSheet("""
            font-size: 14px;
            font-weight: 500;
            color: #007AFF;
            margin-bottom: 10px;
        """)
        layout.addWidget(mode_label)
        
        # Time picker
        time_layout = QHBoxLayout()
        time_layout.setSpacing(10)
        time_layout.setAlignment(Qt.AlignCenter)
        
        # Hours
        self.hours_spin = QSpinBox()
        self.hours_spin.setRange(0, 8)
        self.hours_spin.setValue(1)
        self.hours_spin.setStyleSheet("""
            QSpinBox {
                padding: 8px;
                font-size: 16px;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                min-width: 60px;
                background-color: white;
                color: #1d1d1f;
            }
            QSpinBox::up-button {
                subcontrol-origin: border;
                subcontrol-position: top right;
                width: 20px;
                border-left: 1px solid #d1d1d6;
                border-bottom: 1px solid #d1d1d6;
                border-top-right-radius: 8px;
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
                border-bottom-right-radius: 8px;
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
        """)
        
        hours_label = QLabel("hours")
        hours_label.setStyleSheet("font-size: 16px; color: #86868b;")
        
        # Minutes
        self.minutes_spin = QSpinBox()
        self.minutes_spin.setRange(0, 59)
        self.minutes_spin.setValue(30)
        self.minutes_spin.setStyleSheet(self.hours_spin.styleSheet())
        
        minutes_label = QLabel("minutes")
        minutes_label.setStyleSheet("font-size: 16px; color: #86868b;")
        
        time_layout.addWidget(self.hours_spin)
        time_layout.addWidget(hours_label)
        time_layout.addWidget(self.minutes_spin)
        time_layout.addWidget(minutes_label)
        
        layout.addLayout(time_layout)
        
        # Buttons
        button_layout = QHBoxLayout()
        
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        cancel_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
                font-size: 14px;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: white;
            }
            QPushButton:hover { background-color: #f5f5f7; }
        """)
        
        ok_btn = QPushButton("Next")
        ok_btn.clicked.connect(self.accept_time)
        ok_btn.setDefault(True)
        ok_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
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
        button_layout.addWidget(ok_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def showEvent(self, event):
        """Override showEvent to ensure proper focus and visibility"""
        super().showEvent(event)
        # Force the window to come to the front and stay there
        self.raise_()
        self.activateWindow()
        self.setFocus()
    
    def accept_time(self):
        self.duration_minutes = self.hours_spin.value() * 60 + self.minutes_spin.value()
        if self.duration_minutes > 0:
            self.dialog_result = QDialog.Accepted
            self.accept()
    
    def reject(self):
        self.dialog_result = QDialog.Rejected
        super().reject()

class StreamlinedTodoDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.goals_text = ""
        self.analyzed_goals = []
        self.plugin_tasks = []
        self.ai_analysis = None
        self.init_ui()
        
        # Automatically get plugin tasks in background
        QTimer.singleShot(100, self.gather_plugin_tasks)
    
    def init_ui(self):
        self.setWindowTitle('Focus Session')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(550, 450)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # Add shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 80))
        shadow.setOffset(0, 10)
        self.setGraphicsEffect(shadow)
        
        self.center_window()
        
        self.setStyleSheet("""
            QDialog {
                background-color: white;
                border-radius: 20px;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)
        
        # Top bar with settings gear icon
        top_bar = QHBoxLayout()
        top_bar.addStretch()
        
        gear_btn = QPushButton("⚙")
        gear_btn.setFixedSize(32, 32)
        gear_btn.clicked.connect(self.open_settings)
        gear_btn.setStyleSheet("""
            QPushButton {
                font-size: 18px;
                border: none;
                border-radius: 16px;
                background-color: #f5f5f7;
                color: #666;
            }
            QPushButton:hover { 
                background-color: #e8e8ed; 
                color: #333;
            }
        """)
        top_bar.addWidget(gear_btn)
        layout.addLayout(top_bar)
        
        # Title
        title = QLabel("What would you like to focus on?")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 20px;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 10px;
        """)
        layout.addWidget(title)
        
        # Subtitle
        subtitle = QLabel("AI will automatically organize your session and determine the optimal focus modes")
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setWordWrap(True)
        subtitle.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
        """)
        layout.addWidget(subtitle)
        
        # Goals text area with improved placeholder
        self.goals_input = QTextEdit()
        self.goals_input.setPlaceholderText("Enter your goals naturally...\n\n• Finish quarterly report (due tomorrow)\n• Respond to client emails\n• Plan team meetings for next week\n• Review and approve design mockups\n\nAI will automatically:\n✓ Estimate time needed\n✓ Choose focus modes\n✓ Prioritize by urgency")
        self.goals_input.setStyleSheet("""
            QTextEdit {
                padding: 16px;
                font-size: 14px;
                border: 2px solid #e8e8ed;
                border-radius: 12px;
                background-color: #fafafa;
                line-height: 1.4;
            }
            QTextEdit:focus {
                border-color: #007aff;
                background-color: white;
            }
        """)
        layout.addWidget(self.goals_input)
        
        # Plugin tasks indicator (initially hidden)
        self.plugin_indicator = QLabel()
        self.plugin_indicator.setAlignment(Qt.AlignCenter)
        self.plugin_indicator.setStyleSheet("""
            font-size: 12px;
            color: #007aff;
            padding: 6px;
        """)
        self.plugin_indicator.hide()
        layout.addWidget(self.plugin_indicator)
        
        # Buttons
        button_layout = QHBoxLayout()
        button_layout.addStretch()
        
        self.start_btn = QPushButton("Start AI-Powered Session")
        self.start_btn.clicked.connect(self.start_session)
        self.start_btn.setDefault(True)
        self.start_btn.setStyleSheet("""
            QPushButton {
                padding: 12px 24px;
                font-size: 14px;
                font-weight: 600;
                border: none;
                border-radius: 8px;
                background-color: #007aff;
                color: white;
            }
            QPushButton:hover { background-color: #0056cc; }
            QPushButton:disabled { 
                background-color: #cccccc; 
                color: #666666; 
            }
        """)
        
        button_layout.addWidget(self.start_btn)
        layout.addLayout(button_layout)
        self.setLayout(layout)
        
        # Focus on text input
        self.goals_input.setFocus()
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def open_settings(self):
        """Open the plugin settings dialog"""
        try:
            from plugin_settings_dialog import PluginSettingsDialog
            # Create settings dialog as a child of this dialog to inherit modality properly
            settings_dialog = PluginSettingsDialog(self)
            settings_dialog.setWindowFlags(Qt.Dialog | Qt.WindowStaysOnTopHint)
            settings_dialog.setWindowModality(Qt.ApplicationModal)  # Block everything
            settings_dialog.show()
            settings_dialog.raise_()
            settings_dialog.activateWindow()
        except ImportError:
            print("Settings dialog not available")
        except Exception as e:
            print(f"Error opening settings: {e}")
            import traceback
            traceback.print_exc()
    
    def gather_plugin_tasks(self):
        """Silently gather plugin-injected tasks in background"""
        try:
            from plugin_system import plugin_manager
            # Get plugin tasks without showing dialog
            self.plugin_tasks = plugin_manager.call_goals_analyzed_hooks([], "")
            
            if self.plugin_tasks:
                count = len(self.plugin_tasks)
                self.plugin_indicator.setText(f"✓ Found {count} additional task{'s' if count != 1 else ''} from plugins")
                self.plugin_indicator.show()
                
        except Exception as e:
            print(f"Error gathering plugin tasks: {e}")
    
    def start_session(self):
        """Process goals with AI and start the session"""
        self.goals_text = self.goals_input.toPlainText().strip()
        
        if not self.goals_text and not self.plugin_tasks:
            # Show gentle reminder
            self.goals_input.setStyleSheet("""
                QTextEdit {
                    padding: 16px;
                    font-size: 14px;
                    border: 2px solid #ff3b30;
                    border-radius: 12px;
                    background-color: #fff5f5;
                    line-height: 1.4;
                }
            """)
            self.goals_input.setPlaceholderText("Please enter at least one goal to get started...")
            return
        
        # Combine user goals with plugin tasks
        all_goals = []
        if self.goals_text:
            # Parse user goals (simple fallback parsing)
            user_goals = self.fallback_analysis(self.goals_text)
            all_goals.extend(user_goals)
        
        all_goals.extend(self.plugin_tasks)
        
        # Hide the todo entry screen
        self.hide()
        
        # Show modern loading dialog while AI analyzes
        self.loading_dialog = AILoadingDialog(self)
        
        # Start AI analysis immediately, then show modal dialog
        self.start_ai_analysis(all_goals)
        
        # Show loading dialog modally - this will block until analysis is complete
        result = self.loading_dialog.exec_()
        
        # Continue with the flow after loading completes
        if result == QDialog.Accepted and hasattr(self, 'analyzed_goals'):
            self.accept()  # This will close the todo dialog and proceed to visualization
        else:
            self.show()  # Show todo entry again if something went wrong
    
    def start_ai_analysis(self, all_goals):
        """Start AI analysis after loading dialog is shown"""
        # Start AI analysis in background thread
        self.ai_worker = AIAnalysisWorker(all_goals)
        self.ai_worker.finished.connect(self.on_ai_analysis_complete)
        self.ai_worker.error.connect(self.on_ai_analysis_error)
        self.ai_worker.start()
    
    def on_ai_analysis_complete(self, all_goals, ai_analysis):
        """Handle successful AI analysis completion"""
        self.analyzed_goals = all_goals
        self.ai_analysis = ai_analysis
        
        # Complete loading animation - this will close the modal dialog
        self.loading_dialog.finish_loading()
    
    def on_ai_analysis_error(self, all_goals, error_msg):
        """Handle AI analysis error with fallback"""
        print(f"Error in AI analysis: {error_msg}")
        
        # Use fallback analysis
        self.analyzed_goals = all_goals
        self.ai_analysis = None
        
        # Complete loading with fallback message - this will close the modal dialog
        self.loading_dialog.status_label.setText("Using fallback analysis...")
        self.loading_dialog.finish_loading()
    
    def fallback_analysis(self, goals_text):
        """Simple goal parsing fallback when AI is not available"""
        lines = [line.strip() for line in goals_text.split('\n') if line.strip()]
        if not lines:
            return []
        
        # If it's a single paragraph, try to split on common delimiters
        if len(lines) == 1:
            text = lines[0]
            # Try splitting on bullet points, numbers, semicolons, or "and"
            import re
            
            # Split on bullet points or numbers
            bullet_split = re.split(r'[•·\-*]\s*|\d+\.\s*', text)
            bullet_split = [item.strip() for item in bullet_split if item.strip()]
            
            if len(bullet_split) > 1:
                return bullet_split
            
            # Split on semicolons
            semicolon_split = [item.strip() for item in text.split(';') if item.strip()]
            if len(semicolon_split) > 1:
                return semicolon_split
            
            # Split on " and "
            and_split = [item.strip() for item in text.split(' and ') if item.strip()]
            if len(and_split) > 1:
                return and_split
            
            return [text]
        
        return lines

class AILoadingDialog(QDialog):
    """Modern loading screen with fluid animations for AI analysis"""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.current_step = 0
        self.steps = [
            "Parsing your goals...",
            "Analyzing task complexity...", 
            "Calculating time estimates...",
            "Selecting optimal focus modes...",
            "Organizing session structure...",
            "Finalizing your plan..."
        ]
        self.floating_dots = []
        self.animation_group = None
        self.init_ui()
        self.start_animation()
    
    def init_ui(self):
        self.setWindowTitle('AI Planning Session')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(450, 350)  # Slightly larger to feel more like a replacement
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.Dialog)
        self.setModal(True)  # Make it modal to ensure focus
        
        # Add shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 80))
        shadow.setOffset(0, 10)
        self.setGraphicsEffect(shadow)
        
        self.center_window()
        self.raise_()  # Bring to front
        self.activateWindow()  # Activate window
        self.show()  # Ensure it's visible immediately
        
        self.setStyleSheet("""
            QDialog {
                background-color: white;
                border-radius: 20px;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(40, 40, 40, 40)
        layout.setSpacing(30)
        
        # App icon with proper sizing to prevent cropping
        self.ai_label = QLabel()
        self.ai_label.setAlignment(Qt.AlignCenter)
        self.ai_label.setFixedSize(80, 80)  # Give enough space for the icon
        self.ai_label.setStyleSheet("""
            margin-bottom: 20px;
        """)
        
        # Set app icon with proper scaling
        app_icon = get_app_icon()
        if app_icon and not app_icon.isNull():
            pixmap = app_icon.pixmap(64, 64)  # 64x64 icon size
            self.ai_label.setPixmap(pixmap)
            self.ai_label.setScaledContents(False)  # Maintain aspect ratio
        else:
            # Fallback to text if icon not available
            self.ai_label.setText("🧠")
            self.ai_label.setStyleSheet("""
                font-size: 48px;
                margin-bottom: 20px;
            """)
        
        # Icon breathing animation disabled per user request
        # self.icon_breathing = QPropertyAnimation(self.ai_label, b"geometry")
        # self.icon_breathing.setDuration(2000)
        # self.icon_breathing.setLoopCount(-1)  # Infinite loop
        # self.icon_breathing.setEasingCurve(QEasingCurve.InOutSine)
        
        # Create horizontal layout to center the icon
        icon_layout = QHBoxLayout()
        icon_layout.addStretch()
        icon_layout.addWidget(self.ai_label)
        icon_layout.addStretch()
        layout.addLayout(icon_layout)
        
        # Title
        title = QLabel("AI Planning Your Session")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 20px;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 10px;
        """)
        layout.addWidget(title)
        
        # Create floating dots container
        self.dots_container = QWidget()
        self.dots_container.setFixedHeight(60)
        self.create_floating_dots()
        layout.addWidget(self.dots_container)
        
        # Enhanced progress bar with smooth animation
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 0)  # Indeterminate
        self.progress_bar.setStyleSheet("""
            QProgressBar {
                border: none;
                border-radius: 8px;
                background-color: #f0f0f2;
                height: 16px;
                text-align: center;
            }
            QProgressBar::chunk {
                border-radius: 8px;
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, 
                    stop:0 #007aff, stop:0.3 #5ac8fa, stop:0.7 #30d158, stop:1 #007aff);
                animation: slide 2s infinite;
            }
        """)
        layout.addWidget(self.progress_bar)
        
        # Status text
        self.status_label = QLabel(self.steps[0])
        self.status_label.setAlignment(Qt.AlignCenter)
        self.status_label.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
            margin-top: 10px;
        """)
        layout.addWidget(self.status_label)
        
        self.setLayout(layout)
    
    def create_floating_dots(self):
        """Create floating dots for enhanced visual appeal"""
        colors = ['#007aff', '#30d158', '#ff9500', '#5ac8fa', '#af52de', '#ff375f']
        
        # Create 6 floating dots
        for i in range(6):
            dot = QLabel()
            dot.setParent(self.dots_container)
            dot.setStyleSheet(f"""
                QLabel {{
                    background-color: {colors[i]};
                    border-radius: 6px;
                }}
            """)
            dot.setFixedSize(12, 12)
            
            # Position dots in a pleasing arrangement
            x_pos = 60 + (i * 55)  # Spread across width
            y_pos = 20 + (i % 2) * 20  # Alternate heights
            dot.move(x_pos, y_pos)
            
            self.floating_dots.append(dot)
            
    def start_floating_animation(self):
        """Start the floating dots animation"""
        if self.animation_group:
            self.animation_group.stop()
            
        from PyQt5.QtCore import QParallelAnimationGroup, QPoint
        self.animation_group = QParallelAnimationGroup()
        
        for i, dot in enumerate(self.floating_dots):
            # Create smooth floating motion
            animation = QPropertyAnimation(dot, b"pos")
            animation.setDuration(3000 + (i * 200))  # Stagger timing
            animation.setLoopCount(-1)  # Infinite
            animation.setEasingCurve(QEasingCurve.InOutSine)
            
            # Create floating motion - move up and down
            start_pos = dot.pos()
            end_pos = QPoint(start_pos.x(), start_pos.y() - 20)
            
            animation.setKeyValueAt(0.0, start_pos)
            animation.setKeyValueAt(0.5, end_pos)
            animation.setKeyValueAt(1.0, start_pos)
            
            # Add opacity animation for fade effect
            opacity_animation = QPropertyAnimation(dot, b"windowOpacity")
            opacity_animation.setDuration(2000 + (i * 150))
            opacity_animation.setLoopCount(-1)
            opacity_animation.setEasingCurve(QEasingCurve.InOutQuad)
            opacity_animation.setKeyValueAt(0.0, 0.3)
            opacity_animation.setKeyValueAt(0.5, 1.0)
            opacity_animation.setKeyValueAt(1.0, 0.3)
            
            self.animation_group.addAnimation(animation)
            self.animation_group.addAnimation(opacity_animation)
            
        self.animation_group.start()
        
    def start_icon_breathing(self):
        """Start the breathing animation for the icon"""
        from PyQt5.QtCore import QRect
        
        # Get current geometry
        current_rect = self.ai_label.geometry()
        center_x = current_rect.center().x()
        center_y = current_rect.center().y()
        
        # Create breathing effect - slightly larger and smaller
        normal_rect = QRect(center_x - 32, center_y - 32, 64, 64)
        expanded_rect = QRect(center_x - 36, center_y - 36, 72, 72)
        
        self.icon_breathing.setKeyValueAt(0.0, normal_rect)
        self.icon_breathing.setKeyValueAt(0.5, expanded_rect)
        self.icon_breathing.setKeyValueAt(1.0, normal_rect)
        
        self.icon_breathing.start()
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def start_animation(self):
        """Start the step-by-step animation"""
        # Start floating dots animation
        QTimer.singleShot(100, self.start_floating_animation)  # Small delay to ensure UI is ready
        
        # Start icon breathing animation  
        # QTimer.singleShot(200, self.start_icon_breathing)  # Icon breathing disabled
        
        # Start step cycling
        self.step_timer = QTimer()
        self.step_timer.timeout.connect(self.next_step)
        self.step_timer.start(1800)  # Slightly slower for better readability
    
    def next_step(self):
        """Move to next step in the animation with enhanced transitions"""
        from PyQt5.QtCore import QPoint
        
        self.current_step = (self.current_step + 1) % len(self.steps)
        
        # Create smooth slide-up and fade transition
        self.slide_out_animation = QPropertyAnimation(self.status_label, b"pos")
        self.slide_out_animation.setDuration(400)
        self.slide_out_animation.setEasingCurve(QEasingCurve.OutCubic)
        
        current_pos = self.status_label.pos()
        slide_up_pos = QPoint(current_pos.x(), current_pos.y() - 20)
        self.slide_out_animation.setStartValue(current_pos)
        self.slide_out_animation.setEndValue(slide_up_pos)
        
        # Combine with fade out
        self.fade_out_animation = QPropertyAnimation(self.status_label, b"windowOpacity")
        self.fade_out_animation.setDuration(400)
        self.fade_out_animation.setStartValue(1.0)
        self.fade_out_animation.setEndValue(0.0)
        self.fade_out_animation.setEasingCurve(QEasingCurve.OutCubic)
        self.fade_out_animation.finished.connect(self.fade_in_new_text)
        
        # Start both animations
        self.slide_out_animation.start()
        self.fade_out_animation.start()
    
    def fade_in_new_text(self):
        """Fade in the new step text with slide-down effect"""
        from PyQt5.QtCore import QPoint
        
        self.status_label.setText(self.steps[self.current_step])
        
        # Position for slide-down entrance
        current_pos = self.status_label.pos()
        slide_down_start = QPoint(current_pos.x(), current_pos.y() + 20)
        self.status_label.move(slide_down_start)
        
        # Slide down animation
        self.slide_in_animation = QPropertyAnimation(self.status_label, b"pos")
        self.slide_in_animation.setDuration(500)
        self.slide_in_animation.setEasingCurve(QEasingCurve.OutCubic)
        self.slide_in_animation.setStartValue(slide_down_start)
        self.slide_in_animation.setEndValue(current_pos)
        
        # Fade in animation
        self.fade_in_animation = QPropertyAnimation(self.status_label, b"windowOpacity")
        self.fade_in_animation.setDuration(500)
        self.fade_in_animation.setStartValue(0.0)
        self.fade_in_animation.setEndValue(1.0)
        self.fade_in_animation.setEasingCurve(QEasingCurve.OutCubic)
        
        # Start both animations
        self.slide_in_animation.start()
        self.fade_in_animation.start()
    
    def finish_loading(self):
        """Complete the loading process"""
        # Stop all running animations and timers
        if hasattr(self, 'step_timer'):
            self.step_timer.stop()
        if hasattr(self, 'animation_group') and self.animation_group:
            self.animation_group.stop()
        if hasattr(self, 'icon_breathing') and self.icon_breathing:
            self.icon_breathing.stop()
        if hasattr(self, 'fade_out_animation') and self.fade_out_animation:
            self.fade_out_animation.stop()
        if hasattr(self, 'fade_in_animation') and self.fade_in_animation:
            self.fade_in_animation.stop()
        if hasattr(self, 'slide_out_animation') and self.slide_out_animation:
            self.slide_out_animation.stop()
        if hasattr(self, 'slide_in_animation') and self.slide_in_animation:
            self.slide_in_animation.stop()
        
        # Set success message
        self.status_label.setWindowOpacity(1.0)  # Ensure full opacity
        self.status_label.setText("Session plan ready! ✓")
        self.status_label.setStyleSheet("""
            font-size: 14px;
            color: #30d158;
            font-weight: 600;
            margin-top: 10px;
        """)
        
        # Complete progress bar
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(100)
        self.progress_bar.setStyleSheet("""
            QProgressBar {
                border: none;
                border-radius: 6px;
                background-color: #e8e8ed;
                height: 12px;
            }
            QProgressBar::chunk {
                border-radius: 6px;
                background-color: #30d158;
            }
        """)
        
        # Auto-close after brief success display and accept the dialog
        QTimer.singleShot(1500, self.accept)  # This will return QDialog.Accepted

class AIAnalysisWorker(QThread):
    """Background worker for AI analysis to prevent UI freezing"""
    
    finished = pyqtSignal(list, dict)  # goals, ai_analysis
    error = pyqtSignal(list, str)      # goals, error_message
    
    def __init__(self, goals):
        super().__init__()
        self.goals = goals
    
    def run(self):
        """Run AI analysis in background thread"""
        try:
            from gemini_service import gemini_service
            ai_analysis = gemini_service.analyze_session_goals(self.goals)
            self.finished.emit(self.goals, ai_analysis)
        except Exception as e:
            error_msg = str(e)
            self.error.emit(self.goals, error_msg)

class VideoPlayerWindow(QWidget):
    """Fullscreen video player for focus mode transitions"""
    
    finished = pyqtSignal()  # Emitted when video ends or is skipped
    
    def __init__(self, mode, screen_geometry=None, parent=None):
        super().__init__(parent)
        self.mode = mode
        self.screen_geometry = screen_geometry
        self.video_path = None
        self.fade_timer = None
        self.fade_animation = None
        self.init_ui()
        self.init_video()
    
    def init_ui(self):
        """Initialize the fullscreen video player UI"""
        self.setWindowTitle(f'{self.mode.title()} Mode')
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        self.setAttribute(Qt.WA_DeleteOnClose)
        
        # Set geometry for specific screen if provided
        if self.screen_geometry:
            self.setGeometry(self.screen_geometry)
            self.showFullScreen()
        else:
            # Fallback to regular fullscreen
            self.showFullScreen()
        
        self.setStyleSheet("background-color: black;")
        
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        
        if VIDEO_SUPPORT:
            # Video widget
            self.video_widget = QVideoWidget()
            self.video_widget.setAspectRatioMode(Qt.KeepAspectRatioByExpanding)
            layout.addWidget(self.video_widget)
            
            # Media player
            self.media_player = QMediaPlayer()
            self.media_player.setVideoOutput(self.video_widget)
            
            # Connect signals
            self.media_player.mediaStatusChanged.connect(self.on_media_status_changed)
            self.media_player.positionChanged.connect(self.on_position_changed)
            self.media_player.error.connect(self.on_media_error)
        else:
            # Fallback: simple text display
            fallback_label = QLabel(f"Entering {self.mode.replace('_', ' ').title()} Mode...")
            fallback_label.setAlignment(Qt.AlignCenter)
            fallback_label.setStyleSheet("""
                font-size: 48px;
                color: white;
                font-weight: 300;
            """)
            layout.addWidget(fallback_label)
            
            # Auto-close after 3 seconds
            QTimer.singleShot(3000, self.finish_playback)
        
        self.setLayout(layout)
    
    def init_video(self):
        """Initialize video file path and check if it exists"""
        script_dir = os.path.dirname(os.path.abspath(__file__))
        video_filename = f"{self.mode}.mp4"
        self.video_path = os.path.join(script_dir, "videos", video_filename)
        
        if VIDEO_SUPPORT and os.path.exists(self.video_path):
            print(f"Found video for {self.mode} mode: {video_filename}")
            # Load and play video
            media_content = QMediaContent(QUrl.fromLocalFile(self.video_path))
            self.media_player.setMedia(media_content)
            self.media_player.play()
        else:
            print(f"No video found for {self.mode} mode, will proceed directly to session")
            # Skip video and proceed immediately
            QTimer.singleShot(500, self.finish_playback)
    
    def on_media_status_changed(self, status):
        """Handle media player status changes"""
        if status == QMediaPlayer.LoadedMedia:
            print(f"Video loaded for {self.mode} mode")
        elif status == QMediaPlayer.EndOfMedia:
            print(f"Video finished for {self.mode} mode")
            # Don't call finish_playback here if fade is running
            if not hasattr(self, 'fade_animation') or not self.fade_animation or self.fade_animation.state() != QPropertyAnimation.Running:
                self.finish_playback()
        elif status == QMediaPlayer.InvalidMedia:
            print(f"Invalid video file for {self.mode} mode")
            self.finish_playback()
    
    def on_position_changed(self, position):
        """Handle video position changes for fade-out effect and plugin triggers"""
        if not VIDEO_SUPPORT or not self.media_player:
            return
            
        duration = self.media_player.duration()
        if duration > 0:
            # Trigger plugins at 50% video completion (halfway through)
            progress_percent = (position / duration) * 100
            if progress_percent >= 50 and not hasattr(self, '_plugins_triggered'):
                self._plugins_triggered = True
                self.trigger_focus_plugins()
            
            # Start fade-out during last 1 second
            time_remaining = duration - position
            if time_remaining <= 1000 and not self.fade_animation:  # 1 second = 1000ms
                self.start_fade_out()
    
    def trigger_focus_plugins(self):
        """Trigger plugin focus start hooks during video playback"""
        try:
            from plugin_system import plugin_manager
            print(f"Triggering focus start plugins during {self.mode} video")
            
            # Create session start data for plugins
            session_data = {
                'mode': self.mode,
                'start_time': datetime.now(),
                'trigger_point': 'video_halfway',
                'video_active': True
            }
            
            # Call session start hooks (for things like turning on lamps, etc.)
            plugin_manager.call_session_start_hooks(session_data)
            
        except Exception as e:
            print(f"Error triggering focus plugins during video: {e}")
            # Don't let plugin errors break video playback
            import traceback
            traceback.print_exc()
    
    def start_fade_out(self):
        """Start fade-out animation during last 1 second"""
        if self.fade_animation and self.fade_animation.state() == QPropertyAnimation.Running:
            return  # Already fading
        
        print(f"Starting fade-out for {self.mode} mode video")
        
        # Ensure we start at full opacity
        self.setWindowOpacity(1.0)
        
        self.fade_animation = QPropertyAnimation(self, b"windowOpacity")
        self.fade_animation.setDuration(1000)  # 1 second fade
        self.fade_animation.setStartValue(1.0)
        self.fade_animation.setEndValue(0.0)
        self.fade_animation.setEasingCurve(QEasingCurve.OutCubic)
        
        # Connect fade completion to tab out and background cleanup
        self.fade_animation.finished.connect(self.finish_playbook_after_fade)
        self.fade_animation.start()
        
        print(f"Fade animation started for {self.mode} mode video")
    
    def on_media_error(self, error):
        """Handle media player errors"""
        print(f"Video error for {self.mode} mode: {error}")
        self.finish_playback()
    
    def finish_playbook_after_fade(self):
        """Called when fade animation finishes - tab out and cleanup in background"""
        print(f"Fade complete for {self.mode} mode - tabbing out")
        
        # Tab out of the video window (lose focus) by activating Finder
        try:
            import subprocess
            subprocess.run([
                'osascript', '-e',
                'tell application "Finder" to activate'
            ], capture_output=True, timeout=1)  # Reduced timeout
            print("Tabbed out to Finder")
        except Exception as e:
            print(f"Could not tab out: {e}")
        
        # Immediate cleanup and signal - no delay needed
        self.background_cleanup_and_signal()
    
    def background_cleanup_and_signal(self):
        """Background cleanup and signal emission"""
        # Prevent multiple calls
        if hasattr(self, '_finished'):
            return
        self._finished = True
        
        print(f"Video transition complete for {self.mode} mode")
        
        # Immediate media cleanup
        if VIDEO_SUPPORT and hasattr(self, 'media_player'):
            try:
                self.media_player.stop()
                self.media_player.setMedia(QMediaContent())
            except Exception as e:
                print(f"Media cleanup error: {e}")
        
        # Emit signal immediately
        self.finished.emit()
        
        # Close window immediately
        self.close()
    
    def finish_playback(self):
        """Clean up and signal completion (for non-fade endings)"""
        # If fade is running, let it handle the completion
        if hasattr(self, 'fade_animation') and self.fade_animation and self.fade_animation.state() == QPropertyAnimation.Running:
            return
        
        # For immediate finish (errors, no fade), do direct cleanup
        self.background_cleanup_and_signal()
    
    def keyPressEvent(self, event):
        """Handle key presses (ESC to skip, but disabled for focus sessions)"""
        # For focus sessions, we don't allow skipping videos
        # Videos should be short (30-60 seconds) and non-skippable
        if event.key() == Qt.Key_Escape:
            print("Video skip attempted but disabled during focus session")
        super().keyPressEvent(event)
    
    def closeEvent(self, event):
        """Handle window close event"""
        if VIDEO_SUPPORT and hasattr(self, 'media_player'):
            self.media_player.stop()
        event.accept()



class MultiSectionSessionManager(QObject):
    """Manages multi-section focus sessions with video transitions"""
    
    section_completed = pyqtSignal()  # Signal for section completion
    
    def __init__(self, session_structure, final_goals, app):
        super().__init__()
        self.session_structure = session_structure
        self.final_goals = final_goals
        self.app = app
        self.current_section_index = 0
        self.progress_popup = None
        self.current_video = None
        self.section_stats = []  # Track completion stats per section
        
    def start_session(self):
        """Start the multi-section session"""
        if not self.session_structure:
            print("No session structure available")
            return
            
        print(f"Starting multi-section session with {len(self.session_structure)} sections")
        
        # Initialize section stats
        for i, section in enumerate(self.session_structure):
            self.section_stats.append({
                'section_index': i,
                'mode': section['mode'],
                'planned_duration': section['duration_minutes'],
                'actual_duration': 0,
                'todos_planned': len(section.get('todos', [])),
                'todos_completed': 0,
                'start_time': None,
                'end_time': None
            })
        
        # Start first section
        self.start_section(0)
    
    def start_section(self, section_index):
        """Start a specific section with video transition"""
        if section_index >= len(self.session_structure):
            # All sections complete - show final summary
            self.show_final_summary()
            return
            
        self.current_section_index = section_index
        section = self.session_structure[section_index]
        mode = section['mode']
        duration = section['duration_minutes']
        todos = section.get('todos', [])
        
        print(f"Starting section {section_index + 1}/{len(self.session_structure)}: {mode} mode ({duration}m)")
        
        # Record start time
        self.section_stats[section_index]['start_time'] = datetime.now()
        
        # Play mode video transition
        self.play_mode_video(mode, lambda: self.start_focus_section(section))
    
    def play_mode_video(self, mode, callback):
        """Play video for mode transition"""
        # Check if video exists before creating window
        script_dir = os.path.dirname(os.path.abspath(__file__))
        video_filename = f"{mode}.mp4"
        video_path = os.path.join(script_dir, "videos", video_filename)
        
        print(f"DEBUG: Checking video for mode '{mode}' at path: {video_path}")
        print(f"DEBUG: VIDEO_SUPPORT = {VIDEO_SUPPORT}")
        print(f"DEBUG: File exists = {os.path.exists(video_path) if video_path else False}")
        
        if VIDEO_SUPPORT and os.path.exists(video_path):
            # Video exists, show it on primary display only
            print(f"Playing transition video for {mode} mode")
            self.current_video = VideoPlayerWindow(mode)
            def cleanup_and_callback():
                # Clean up video reference
                if hasattr(self, 'current_video') and self.current_video:
                    self.current_video.close()
                    self.current_video = None
                callback()
            self.current_video.finished.connect(cleanup_and_callback)
            self.current_video.show()
        else:
            # No video, trigger plugins immediately and skip to callback
            print(f"No video for {mode} mode, proceeding directly to session")
            
            # Trigger plugins since there's no video to do it
            def trigger_plugins_and_callback():
                try:
                    from plugin_system import plugin_manager
                    session_data = {
                        'mode': mode,
                        'start_time': datetime.now(),
                        'trigger_point': 'no_video',
                        'video_active': False
                    }
                    plugin_manager.call_session_start_hooks(session_data)
                    print(f"Triggered session start plugins for {mode} (no video)")
                except Exception as e:
                    print(f"Error triggering plugins (no video): {e}")
                
                callback()
            
            QTimer.singleShot(100, trigger_plugins_and_callback)  # Small delay for smooth transition
    
    def start_focus_section(self, section):
        """Start the actual focus section after video"""
        mode = section['mode'] 
        duration = section['duration_minutes']
        todos = section.get('todos', [])
        
        # Launch focus mode blocking
        self.launch_focus_mode(mode)
        
        # Collect ALL todos from ALL sections for comprehensive display
        all_todos = []
        for sect in self.session_structure:
            section_todos = sect.get('todos', [])
            all_todos.extend(section_todos)
        
        # Start progress tracking for this section with ALL todos
        popup_interval = get_popup_interval_setting()
        self.progress_popup = ProgressPopup(
            duration, 
            all_todos,  # Pass ALL todos instead of just current section
            popup_interval=popup_interval, 
            parent_launcher=self,
            mode=mode,
            plugins_already_triggered=True,  # Tell popup plugins were triggered during video
            session_structure=self.session_structure,
            current_section_index=self.current_section_index
        )
        
        # Override the session_complete method to trigger section completion WITHOUT showing summary
        original_session_complete = self.progress_popup.session_complete
        def section_complete_wrapper():
            # For multi-section sessions, skip the summary and just do cleanup
            self.progress_popup.progress_timer.stop()
            self.progress_popup.popup_timer.stop() 
            self.progress_popup.app_timer.stop()
            
            # Close progress popup without showing summary
            self.progress_popup.close()
            
            # Trigger section completion
            self.on_section_completed()
        self.progress_popup.session_complete = section_complete_wrapper
        
        # Set progress popup reference for plugin system
        try:
            from plugin_system import plugin_manager
            plugin_manager.set_progress_popup_reference(self.progress_popup)
        except Exception as e:
            print(f"Error setting progress popup reference: {e}")
    
    def get_remaining_sections(self):
        """Get list of remaining sections after current one"""
        remaining = []
        for i in range(self.current_section_index + 1, len(self.session_structure)):
            section = self.session_structure[i]
            remaining.append({
                'mode': section['mode'],
                'duration': section['duration_minutes'],
                'todos_count': len(section.get('todos', []))
            })
        return remaining
    
    def on_section_completed(self):
        """Handle completion of current section"""
        print(f"Section {self.current_section_index + 1} completed")
        
        # Record end time and stats
        stats = self.section_stats[self.current_section_index]
        stats['end_time'] = datetime.now()
        if stats['start_time']:
            stats['actual_duration'] = int((stats['end_time'] - stats['start_time']).total_seconds() / 60)
        
        # Get completion count from progress popup if available
        if self.progress_popup and hasattr(self.progress_popup, 'get_completion_count'):
            stats['todos_completed'] = self.progress_popup.get_completion_count()
        
        # Check if this is the last section
        next_section = self.current_section_index + 1
        is_final_section = next_section >= len(self.session_structure)
        
        if is_final_section:
            # Final section - stop focus mode and call session end hooks
            self.stop_focus_mode()
            self.call_final_session_end_hooks()
            self.show_final_summary()
        else:
            # Not final section - seamless transition without stopping plugins
            print(f"Transitioning from {self.session_structure[self.current_section_index]['mode']} to {self.session_structure[next_section]['mode']} mode")
            
            # Stop focus mode blocking (but keep plugins running)
            self.stop_focus_mode_blocking_only()
            
            # Start next section immediately
            self.start_section(next_section)
    
    def launch_focus_mode(self, mode):
        """Launch focus mode blocking for current section"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            
            # Write current mode to file
            with open(os.path.join(script_dir, 'current_mode'), 'w') as f:
                f.write(mode)
            
            print(f"Launching {mode} focus mode")
            # The actual blocking scripts will run in background
            
        except Exception as e:
            print(f"Error launching focus mode: {e}")
    
    def stop_focus_mode(self):
        """Stop current focus mode with password manager integration (final cleanup)"""
        print("Stopping focus mode for final session completion")
        try:
            # Use the password-enabled cleanup function
            stop_focus_mode_with_password()
            print("Focus mode stopped successfully with password manager")
        except Exception as e:
            print(f"Error stopping focus mode with password: {e}")
            print("Falling back to emergency cleanup")
            self.emergency_cleanup()
    
    def stop_focus_mode_blocking_only(self):
        """Stop only the focus mode blocking (not plugins) for seamless transitions"""
        print("Stopping focus mode blocking for section transition")
        try:
            import subprocess
            script_dir = os.path.dirname(os.path.abspath(__file__))
            
            # Kill focus blocking processes but don't trigger plugin cleanup
            subprocess.run(['pkill', '-f', 'kill_looper'], check=False)
            subprocess.run(['pkill', '-f', 'kill_disallowed'], check=False) 
            subprocess.run(['pkill', '-f', 'monitor_active'], check=False)
            
            print("Focus mode blocking stopped (plugins continue running)")
        except Exception as e:
            print(f"Error stopping focus mode blocking: {e}")
    
    def call_final_session_end_hooks(self):
        """Call session end hooks only for the final session completion"""
        try:
            from plugin_system import plugin_manager
            total_duration = sum(stats['actual_duration'] for stats in self.section_stats)
            total_todos = sum(stats['todos_completed'] for stats in self.section_stats)
            
            session_data = {
                'mode': 'multi_section',
                'sections': self.section_structure,
                'section_stats': self.section_stats,
                'total_duration': total_duration,
                'total_todos_completed': total_todos,
                'final_goals': self.final_goals,
                'end_time': datetime.now(),
                'session_type': 'multi_section'
            }
            
            print("Calling final session end hooks for all plugins")
            plugin_manager.call_session_end_hooks(session_data)
        except Exception as e:
            print(f"Error calling final session end hooks: {e}")
    
    def emergency_cleanup(self):
        """Emergency cleanup if stop script fails"""
        try:
            import signal
            
            # Clear current mode file
            script_dir = os.path.dirname(os.path.abspath(__file__))
            mode_file = os.path.join(script_dir, 'current_mode')
            with open(mode_file, 'w') as f:
                f.write('')
            
            # Kill focus processes directly
            subprocess.run(['pkill', '-f', 'kill_looper'], check=False)
            subprocess.run(['pkill', '-f', 'kill_disallowed'], check=False)
            subprocess.run(['pkill', '-f', 'monitor_active'], check=False)
            
            print("Emergency cleanup completed")
        except Exception as e:
            print(f"Emergency cleanup error: {e}")
    
    def send_ai_reminder_notification(self):
        """Send a system notification reminding user about AI assistant"""
        print("🤖 Focus session started! AI Agent is ready - click the Agent button in your progress popup.")
        
        # Try Python-based notification methods
        notification_sent = False
        
        # Method 1: Try using plyer (cross-platform notifications)
        try:
            from plyer import notification
            notification.notify(
                title='🤖 Focus Session Started',
                message='AI Agent is ready! Click the Agent button.',
                timeout=5
            )
            print("✅ Python notification sent successfully")
            notification_sent = True
        except ImportError:
            print("DEBUG: plyer not available, trying pync...")
        except Exception as e:
            print(f"DEBUG: plyer notification failed: {e}")
        
        # Method 2: Try using pync (macOS specific)
        if not notification_sent:
            try:
                import pync
                pync.notify(
                    'AI Agent is ready! Click the Agent button.',
                    title='🤖 Focus Session Started',
                    sound='Glass'
                )
                print("✅ pync notification sent successfully")
                notification_sent = True
            except ImportError:
                print("DEBUG: pync not available, trying PyQt notifications...")
            except Exception as e:
                print(f"DEBUG: pync notification failed: {e}")
        
        # Method 3: Try PyQt5 system tray notification
        if not notification_sent:
            try:
                from PyQt5.QtWidgets import QSystemTrayIcon
                if hasattr(self, 'app') and QSystemTrayIcon.isSystemTrayAvailable():
                    # Create temporary system tray icon for notification
                    tray_icon = QSystemTrayIcon()
                    tray_icon.setIcon(get_app_icon())
                    tray_icon.show()
                    tray_icon.showMessage(
                        "🤖 Focus Session Started",
                        "AI Agent is ready! Click the Agent button.",
                        QSystemTrayIcon.Information,
                        3000  # 3 seconds
                    )
                    print("✅ QSystemTrayIcon notification sent successfully")
                    notification_sent = True
                else:
                    print("DEBUG: System tray not available")
            except Exception as e:
                print(f"DEBUG: QSystemTrayIcon notification failed: {e}")
        
        # Method 4: Fall back to osascript (macOS terminal-notifier style)
        if not notification_sent:
            try:
                import subprocess
                subprocess.run([
                    'osascript', '-e',
                    'display notification "AI Agent is ready! Click the Agent button." with title "🤖 Focus Session Started"'
                ], capture_output=True, timeout=3)
                print("✅ osascript notification sent successfully")
                notification_sent = True
            except Exception as e:
                print(f"DEBUG: osascript notification failed: {e}")
        
        if not notification_sent:
            print("⚠️  Could not send system notification - all methods failed")
    
    def show_final_summary(self):
        """Show enhanced final session summary after all sections"""
        print("All sections completed - showing enhanced final summary")
        
        # Create and show enhanced summary dialog
        self.final_summary = EnhancedFinalSummaryDialog(
            session_structure=self.session_structure,
            section_stats=self.section_stats,
            final_goals=self.final_goals
        )
        self.final_summary.show()
        self.final_summary.raise_()
        self.final_summary.activateWindow()
        
        # Properly cleanup with password manager before exit
        print("Performing final cleanup with password manager")
        try:
            stop_focus_mode_with_password()
            print("Final cleanup completed successfully")
        except Exception as e:
            print(f"Error during final cleanup: {e}")
        
        # Exit application after proper cleanup
        import sys
        sys.exit(0)
    
    def extend_current_section(self, minutes):
        """Extend current section by specified minutes"""
        if self.current_section_index < len(self.section_stats):
            # Add time to current section
            current_stats = self.section_stats[self.current_section_index]
            current_stats['planned_duration'] += minutes
            
            # Update progress popup if it exists
            if self.progress_popup:
                self.progress_popup.extend_session(minutes)
                
            print(f"Extended current section by {minutes} minutes")
    
    def reduce_current_section(self, minutes):
        """Reduce current section by specified minutes"""
        if self.current_section_index < len(self.section_stats):
            current_stats = self.section_stats[self.current_section_index]
            
            # Don't reduce below 5 minutes
            new_duration = max(5, current_stats['planned_duration'] - minutes)
            actual_reduction = current_stats['planned_duration'] - new_duration
            current_stats['planned_duration'] = new_duration
            
            # Update progress popup if it exists
            if self.progress_popup:
                self.progress_popup.reduce_session(actual_reduction)
                
            print(f"Reduced current section by {actual_reduction} minutes")
    
    def pause_session(self):
        """Pause the current session"""
        print("Session paused")
        # Could implement pause logic here if needed
        
    def resume_session(self):
        """Resume the current session"""
        print("Session resumed")
        # Could implement resume logic here if needed


class EnhancedFinalSummaryDialog(QDialog):
    """Enhanced final summary dialog with comprehensive session analytics and beautiful Apple-style design"""
    
    def __init__(self, session_structure, section_stats, final_goals, parent=None):
        super().__init__(parent)
        self.session_structure = session_structure
        self.section_stats = section_stats
        self.final_goals = final_goals
        
        # Calculate totals
        self.total_time = sum(stats['actual_duration'] for stats in section_stats)
        self.total_todos = sum(stats['todos_completed'] for stats in section_stats)
        self.total_planned_time = sum(stats['planned_duration'] for stats in section_stats)
        
        # Load usage analytics
        self.usage_data = self.load_usage_analytics()
        
        # Mode colors (Apple's vibrant system colors)
        self.mode_colors = {
            "productivity": "#007aff",      # Apple Blue
            "creativity": "#30d158",        # Apple Green  
            "social_media_detox": "#ff9500" # Apple Orange
        }
        
        # Additional accent colors for charts
        self.chart_colors = [
            "#007aff", "#30d158", "#ff9500", "#5ac8fa", "#af52de", "#ff375f",
            "#ffcc02", "#64d2ff", "#bf5af2", "#ff6482", "#32d74b", "#ff9f0a"
        ]
        
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Session Analytics')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(900, 800)  # Larger for comprehensive analytics
        self.setWindowFlags(Qt.Dialog | Qt.WindowStaysOnTopHint)
        
        # Beautiful shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(30)
        shadow.setColor(QColor(0, 0, 0, 60))
        shadow.setOffset(0, 15)
        self.setGraphicsEffect(shadow)
        
        self.center_window()
        
        # Elegant Apple-style design with subtle gradients
        self.setStyleSheet("""
            QDialog {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #ffffff, stop:1 #fafafa);
                border-radius: 24px;
                border: 1px solid rgba(0, 0, 0, 0.08);
            }
            QScrollArea {
                border: none;
                background-color: transparent;
            }
            QScrollBar:vertical {
                border: none;
                background: rgba(0, 0, 0, 0.05);
                width: 8px;
                border-radius: 4px;
                margin: 0;
            }
            QScrollBar::handle:vertical {
                background: rgba(0, 0, 0, 0.2);
                border-radius: 4px;
                min-height: 20px;
                margin: 1px;
            }
            QScrollBar::handle:vertical:hover {
                background: rgba(0, 0, 0, 0.3);
            }
        """)
        
        # Main scroll area for the entire content
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        
        main_widget = QWidget()
        layout = QVBoxLayout(main_widget)
        layout.setContentsMargins(40, 40, 40, 40)
        layout.setSpacing(25)
        
        # Hero Header Section
        self.create_hero_header(layout)
        
        # Key Metrics Dashboard
        self.create_metrics_dashboard(layout)
        
        # Visual Analytics Charts
        self.create_analytics_section(layout)
        
        # Session Timeline & Breakdown
        self.create_session_breakdown(layout)
        
        # App & Website Usage Insights
        self.create_usage_insights(layout)
        
        # Action Buttons
        self.create_action_buttons(layout)
        
        main_scroll.setWidget(main_widget)
        
        # Set the scroll area as the main layout
        dialog_layout = QVBoxLayout()
        dialog_layout.setContentsMargins(0, 0, 0, 0)
        dialog_layout.addWidget(main_scroll)
        self.setLayout(dialog_layout)
    
    def load_usage_analytics(self):
        """Load app and website usage data from log files"""
        try:
            import os
            import re
            from collections import defaultdict, Counter
            
            script_dir = os.path.dirname(os.path.abspath(__file__))
            apps_log = os.path.join(script_dir, 'active_programs.log')
            tabs_log = os.path.join(script_dir, 'browser_tabs.log')
            
            data = {
                'apps': Counter(),
                'websites': Counter(),
                'app_timeline': [],
                'website_timeline': []
            }
            
            # Parse active programs log
            if os.path.exists(apps_log):
                with open(apps_log, 'r') as f:
                    for line in f:
                        if 'Active Programs:' in line:
                            # Extract apps from line like: [2024-01-15 14:30:00] Active Programs: Chrome, Safari, VSCode
                            apps_part = line.split('Active Programs:')[1].strip()
                            if apps_part and apps_part != '{}':
                                apps = [app.strip() for app in apps_part.replace('{', '').replace('}', '').split(',')]
                                for app in apps:
                                    if app and app not in ['Finder', 'Dock', 'SystemUIServer']:
                                        data['apps'][app.strip()] += 1
            
            # Parse browser tabs log  
            if os.path.exists(tabs_log):
                with open(tabs_log, 'r') as f:
                    for line in f:
                        if 'Tabs:' in line:
                            # Extract domains from tab titles
                            tabs_part = line.split('Tabs:')[1].strip()
                            if tabs_part and tabs_part != '{}':
                                # Simple domain extraction from common patterns
                                domains = re.findall(r'https?://(?:www\.)?([^/\s,}]+)', tabs_part)
                                for domain in domains:
                                    data['websites'][domain] += 1
            
            return data
            
        except Exception as e:
            print(f"Error loading usage analytics: {e}")
            return {'apps': Counter(), 'websites': Counter(), 'app_timeline': [], 'website_timeline': []}
    
    def create_hero_header(self, layout):
        """Create beautiful hero header with celebration and key stats"""
        hero_frame = QFrame()
        hero_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(0, 122, 255, 0.05), stop:1 rgba(0, 122, 255, 0.02));
                border-radius: 16px;
                border: 1px solid rgba(0, 122, 255, 0.1);
                padding: 20px;
            }
        """)
        
        hero_layout = QVBoxLayout(hero_frame)
        hero_layout.setSpacing(15)
        
        # Celebration icon with subtle animation effect
        celebration = QLabel("🎯")
        celebration.setAlignment(Qt.AlignCenter)
        celebration.setStyleSheet("""
            font-size: 64px;
            margin-bottom: 10px;
            color: #007aff;
        """)
        hero_layout.addWidget(celebration)
        
        # Main title
        title = QLabel("Session Complete!")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 36px;
            font-weight: 700;
            color: #1d1d1f;
            margin-bottom: 8px;
            letter-spacing: -0.5px;
        """)
        hero_layout.addWidget(title)
        
        # Elegant summary with efficiency
        efficiency = (self.total_time / self.total_planned_time * 100) if self.total_planned_time > 0 else 100
        performance_emoji = "🚀" if efficiency >= 95 else "⭐" if efficiency >= 80 else "👍"
        
        summary_text = f"Completed {len(self.session_structure)} focus modes • {self.total_time:.0f} minutes of focused work"
        if efficiency < 100:
            summary_text += f" • {efficiency:.0f}% efficiency {performance_emoji}"
        
        summary = QLabel(summary_text)
        summary.setAlignment(Qt.AlignCenter)
        summary.setStyleSheet("""
            font-size: 17px;
            color: #8e8e93;
            font-weight: 500;
            line-height: 1.3;
        """)
        hero_layout.addWidget(summary)
        
        layout.addWidget(hero_frame)
    
    def create_metrics_dashboard(self, layout):
        """Create beautiful metrics dashboard with key statistics"""
        metrics_frame = QFrame()
        metrics_frame.setStyleSheet("""
            QFrame {
                background-color: white;
                border-radius: 16px;
                border: 1px solid rgba(0, 0, 0, 0.06);
            }
        """)
        
        metrics_layout = QHBoxLayout(metrics_frame)
        metrics_layout.setContentsMargins(25, 25, 25, 25)
        metrics_layout.setSpacing(30)
        
        # Key metrics with beautiful cards
        time_card = self.create_elegant_metric_card("⏱", "Total Time", f"{self.total_time:.0f}", "minutes", "#007aff")
        tasks_card = self.create_elegant_metric_card("✅", "Tasks", f"{self.total_todos}", "completed", "#30d158") 
        modes_card = self.create_elegant_metric_card("🎯", "Focus Modes", f"{len(self.session_structure)}", "used", "#ff9500")
        
        efficiency = (self.total_time / self.total_planned_time * 100) if self.total_planned_time > 0 else 100
        efficiency_card = self.create_elegant_metric_card("📈", "Efficiency", f"{efficiency:.0f}%", "of planned", "#5ac8fa")
        
        metrics_layout.addWidget(time_card)
        metrics_layout.addWidget(tasks_card)
        metrics_layout.addWidget(modes_card)
        metrics_layout.addWidget(efficiency_card)
        
        layout.addWidget(metrics_frame)
    
    def create_elegant_metric_card(self, icon, label, value, unit, color):
        """Create an elegant metric card with icon, value, and subtle styling"""
        card = QFrame()
        card.setStyleSheet(f"""
            QFrame {{
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(255, 255, 255, 0.95), stop:1 rgba(248, 248, 248, 0.95));
                border-radius: 12px;
                border: 1px solid rgba(0, 0, 0, 0.04);
                padding: 15px;
            }}
            QFrame:hover {{
                border-color: {color}40;
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(255, 255, 255, 1), stop:1 rgba(250, 250, 250, 1));
            }}
        """)
        
        card_layout = QVBoxLayout(card)
        card_layout.setSpacing(8)
        card_layout.setAlignment(Qt.AlignCenter)
        
        # Icon
        icon_label = QLabel(icon)
        icon_label.setAlignment(Qt.AlignCenter)
        icon_label.setStyleSheet(f"font-size: 28px; color: {color}; margin-bottom: 5px;")
        card_layout.addWidget(icon_label)
        
        # Value
        value_label = QLabel(value)
        value_label.setAlignment(Qt.AlignCenter)
        value_label.setStyleSheet(f"""
            font-size: 32px;
            font-weight: 700;
            color: {color};
            margin-bottom: 2px;
        """)
        card_layout.addWidget(value_label)
        
        # Unit
        unit_label = QLabel(unit)
        unit_label.setAlignment(Qt.AlignCenter)
        unit_label.setStyleSheet("""
            font-size: 12px;
            color: #8e8e93;
            font-weight: 500;
            margin-bottom: 5px;
        """)
        card_layout.addWidget(unit_label)
        
        # Label
        label_label = QLabel(label)
        label_label.setAlignment(Qt.AlignCenter)
        label_label.setStyleSheet("""
            font-size: 14px;
            color: #3a3a3c;
            font-weight: 600;
        """)
        card_layout.addWidget(label_label)
        
        return card
    
    def create_analytics_section(self, layout):
        """Create visual analytics section with charts and insights"""
        analytics_frame = QFrame()
        analytics_frame.setStyleSheet("""
            QFrame {
                background-color: white;
                border-radius: 16px;
                border: 1px solid rgba(0, 0, 0, 0.06);
                padding: 25px;
            }
        """)
        
        analytics_layout = QVBoxLayout(analytics_frame)
        analytics_layout.setSpacing(20)
        
        # Section title
        title = QLabel("📊 Session Analytics")
        title.setStyleSheet("""
            font-size: 22px;
            font-weight: 700;
            color: #1d1d1f;
            margin-bottom: 10px;
        """)
        analytics_layout.addWidget(title)
        
        # Time distribution chart
        time_chart = self.create_time_distribution_chart()
        analytics_layout.addWidget(time_chart)
        
        layout.addWidget(analytics_frame)
    
    def create_time_distribution_chart(self):
        """Create a beautiful time distribution visualization"""
        chart_frame = QFrame()
        chart_frame.setFixedHeight(150)  # Increased height for better spacing
        chart_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(248, 248, 248, 0.8), stop:1 rgba(240, 240, 240, 0.8));
                border-radius: 12px;
                border: 1px solid rgba(0, 0, 0, 0.03);
            }
        """)
        
        chart_layout = QVBoxLayout(chart_frame)
        chart_layout.setContentsMargins(20, 15, 20, 15)
        
        # Chart title
        chart_title = QLabel("Time Distribution by Focus Mode")
        chart_title.setStyleSheet("""
            font-size: 15px;
            font-weight: 600;
            color: #3a3a3c;
            margin-bottom: 10px;
        """)
        chart_layout.addWidget(chart_title)
        
        # Progress bars for each mode
        bars_layout = QVBoxLayout()
        bars_layout.setSpacing(15)  # Increased spacing for better readability
        bars_layout.setContentsMargins(0, 5, 0, 5)  # Add top and bottom margins
        
        for section, stats in zip(self.session_structure, self.section_stats):
            mode = section['mode']
            duration = stats['actual_duration']
            percentage = (duration / self.total_time * 100) if self.total_time > 0 else 0
            
            bar_frame = self.create_progress_bar(
                self.get_mode_display_name(mode),
                f"{duration:.0f}m ({percentage:.0f}%)",
                percentage / 100,
                self.mode_colors.get(mode, "#007aff")
            )
            bars_layout.addWidget(bar_frame)
        
        chart_layout.addLayout(bars_layout)
        return chart_frame
    
    def create_progress_bar(self, label, value, progress, color):
        """Create a beautiful animated progress bar"""
        bar_frame = QFrame()
        bar_layout = QHBoxLayout(bar_frame)
        bar_layout.setContentsMargins(0, 0, 0, 0)
        bar_layout.setSpacing(15)
        
        # Label
        label_widget = QLabel(label)
        label_widget.setMinimumWidth(120)
        label_widget.setStyleSheet("""
            font-size: 13px;
            font-weight: 500;
            color: #3a3a3c;
        """)
        bar_layout.addWidget(label_widget)
        
        # Progress bar container
        progress_container = QFrame()
        progress_container.setFixedHeight(8)
        progress_container.setStyleSheet(f"""
            QFrame {{
                background-color: rgba(0, 0, 0, 0.08);
                border-radius: 4px;
            }}
        """)
        
        # Actual progress bar
        progress_bar = QFrame(progress_container)
        progress_width = int(progress_container.width() * progress) if progress > 0 else 0
        progress_bar.setFixedSize(max(4, progress_width), 8)
        progress_bar.setStyleSheet(f"""
            QFrame {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 {color}, stop:1 {color}CC);
                border-radius: 4px;
            }}
        """)
        
        bar_layout.addWidget(progress_container)
        
        # Value
        value_widget = QLabel(value)
        value_widget.setMinimumWidth(80)
        value_widget.setAlignment(Qt.AlignRight)
        value_widget.setStyleSheet("""
            font-size: 12px;
            font-weight: 500;
            color: #8e8e93;
        """)
        bar_layout.addWidget(value_widget)
        
        return bar_frame
    
    def create_session_breakdown(self, layout):
        """Create detailed session breakdown with timeline"""
        breakdown_frame = QFrame()
        breakdown_frame.setStyleSheet("""
            QFrame {
                background-color: white;
                border-radius: 16px;
                border: 1px solid rgba(0, 0, 0, 0.06);
                padding: 25px;
            }
        """)
        
        breakdown_layout = QVBoxLayout(breakdown_frame)
        breakdown_layout.setSpacing(20)
        
        # Section title
        title = QLabel("📅 Session Timeline")
        title.setStyleSheet("""
            font-size: 22px;
            font-weight: 700;
            color: #1d1d1f;
            margin-bottom: 15px;
        """)
        breakdown_layout.addWidget(title)
        
        # Timeline visualization
        timeline = self.create_session_timeline()
        breakdown_layout.addWidget(timeline)
        
        # Section cards
        for i, (section, stats) in enumerate(zip(self.session_structure, self.section_stats)):
            section_card = self.create_elegant_section_card(i + 1, section, stats)
            breakdown_layout.addWidget(section_card)
        
        layout.addWidget(breakdown_frame)
    
    def create_session_timeline(self):
        """Create a beautiful session timeline visualization"""
        timeline_frame = QFrame()
        timeline_frame.setFixedHeight(60)
        timeline_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(248, 248, 248, 0.6), stop:1 rgba(240, 240, 240, 0.6));
                border-radius: 12px;
                border: 1px solid rgba(0, 0, 0, 0.03);
            }
        """)
        
        # Custom paint event for the timeline
        def paint_timeline(event):
            painter = QPainter(timeline_frame)
            painter.setRenderHint(QPainter.Antialiasing)
            
            if not self.session_structure:
                return
                
            margin = 20
            width = timeline_frame.width() - 2 * margin
            height = 20
            y = (timeline_frame.height() - height) // 2
            
            current_x = margin
            for i, (section, stats) in enumerate(zip(self.session_structure, self.section_stats)):
                mode = section['mode']
                duration = stats['actual_duration']
                proportion = duration / self.total_time if self.total_time > 0 else 0
                section_width = int(width * proportion)
                
                # Draw section with gradient
                color = QColor(self.mode_colors.get(mode, "#007aff"))
                painter.fillRect(current_x, y, section_width, height, color)
                
                # Add subtle border
                painter.setPen(QPen(color.darker(110), 1))
                painter.drawRect(current_x, y, section_width, height)
                
                current_x += section_width
            
            painter.end()
        
        timeline_frame.paintEvent = paint_timeline
        return timeline_frame
    
    def create_elegant_section_card(self, number, section, stats):
        """Create an elegant section card with detailed information"""
        card = QFrame()
        mode_color = self.mode_colors.get(section['mode'], "#007aff")
        
        card.setStyleSheet(f"""
            QFrame {{
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(255, 255, 255, 0.95), stop:1 rgba(248, 248, 248, 0.9));
                border-left: 4px solid {mode_color};
                border-radius: 12px;
                border: 1px solid rgba(0, 0, 0, 0.04);
                padding: 15px;
                margin: 2px 0px;
            }}
            QFrame:hover {{
                border-color: {mode_color}40;
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(255, 255, 255, 1), stop:1 rgba(250, 250, 250, 1));
            }}
        """)
        
        card_layout = QVBoxLayout(card)
        card_layout.setSpacing(10)
        
        # Header with mode and timing
        header_layout = QHBoxLayout()
        
        mode_label = QLabel(f"{number}. {self.get_mode_display_name(section['mode'])}")
        mode_label.setStyleSheet(f"""
            font-size: 16px;
            font-weight: 700;
            color: {mode_color};
        """)
        header_layout.addWidget(mode_label)
        
        header_layout.addStretch()
        
        duration_text = f"{stats['actual_duration']:.0f} min"
        if stats['planned_duration'] != stats['actual_duration']:
            duration_text += f" (planned: {stats['planned_duration']:.0f}m)"
        
        duration_label = QLabel(duration_text)
        duration_label.setStyleSheet("""
            font-size: 13px;
            font-weight: 500;
            color: #8e8e93;
        """)
        header_layout.addWidget(duration_label)
        
        card_layout.addLayout(header_layout)
        
        # Todos with beautiful styling
        if section.get('todos'):
            todos_frame = QFrame()
            todos_layout = QVBoxLayout(todos_frame)
            todos_layout.setContentsMargins(0, 5, 0, 5)
            todos_layout.setSpacing(4)
            
            for todo in section['todos'][:3]:  # Show max 3 todos
                todo_item = QLabel(f"• {todo}")
                todo_item.setStyleSheet("""
                    font-size: 13px;
                    color: #3a3a3c;
                    padding: 2px 0px;
                """)
                todos_layout.addWidget(todo_item)
            
            if len(section['todos']) > 3:
                more_label = QLabel(f"... and {len(section['todos']) - 3} more tasks")
                more_label.setStyleSheet("""
                    font-size: 12px;
                    color: #8e8e93;
                    font-style: italic;
                    padding: 2px 0px;
                """)
                todos_layout.addWidget(more_label)
            
            card_layout.addWidget(todos_frame)
        
        return card
    
    def create_usage_insights(self, layout):
        """Create app and website usage insights section"""
        if not any([self.usage_data['apps'], self.usage_data['websites']]):
            return  # Skip if no usage data
        
        usage_frame = QFrame()
        usage_frame.setStyleSheet("""
            QFrame {
                background-color: white;
                border-radius: 16px;
                border: 1px solid rgba(0, 0, 0, 0.06);
                padding: 25px;
            }
        """)
        
        usage_layout = QVBoxLayout(usage_frame)
        usage_layout.setSpacing(20)
        
        # Section title
        title = QLabel("💻 Usage Insights")
        title.setStyleSheet("""
            font-size: 22px;
            font-weight: 700;
            color: #1d1d1f;
            margin-bottom: 15px;
        """)
        usage_layout.addWidget(title)
        
        # Apps and websites layout
        insights_layout = QHBoxLayout()
        insights_layout.setSpacing(30)
        
        # Top apps
        if self.usage_data['apps']:
            apps_section = self.create_usage_section("📱 Most Used Apps", self.usage_data['apps'], "#007aff")
            insights_layout.addWidget(apps_section)
        
        # Top websites - enhanced section
        if self.usage_data['websites']:
            sites_section = self.create_usage_section("🌐 Top Used Sites", self.usage_data['websites'], "#30d158")
            insights_layout.addWidget(sites_section)
        
        usage_layout.addLayout(insights_layout)
        layout.addWidget(usage_frame)
    
    def create_usage_section(self, title, data, color):
        """Create a usage section for apps or websites"""
        section = QFrame()
        section.setStyleSheet(f"""
            QFrame {{
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(248, 248, 248, 0.6), stop:1 rgba(240, 240, 240, 0.4));
                border-radius: 12px;
                border: 1px solid rgba(0, 0, 0, 0.03);
                padding: 15px;
            }}
        """)
        
        section_layout = QVBoxLayout(section)
        section_layout.setSpacing(12)
        
        # Section title
        title_label = QLabel(title)
        title_label.setStyleSheet(f"""
            font-size: 16px;
            font-weight: 600;
            color: {color};
            margin-bottom: 5px;
        """)
        section_layout.addWidget(title_label)
        
        # Top 5 items
        top_items = data.most_common(5)
        for item, count in top_items:
            item_frame = QFrame()
            item_layout = QHBoxLayout(item_frame)
            item_layout.setContentsMargins(0, 0, 0, 0)
            
            item_label = QLabel(item)
            item_label.setStyleSheet("""
                font-size: 13px;
                color: #3a3a3c;
                font-weight: 500;
            """)
            item_layout.addWidget(item_label)
            
            item_layout.addStretch()
            
            # Convert count to approximate time (logs are every ~5-6 seconds)
            # Cap at reasonable session duration and use more conservative estimate
            estimated_minutes = max(1, min(count // 20, 120))  # Conservative: 20 entries = ~1 minute, max 2 hours
            if estimated_minutes >= 60:
                hours = estimated_minutes // 60
                remaining_minutes = estimated_minutes % 60
                time_text = f"{hours}h {remaining_minutes}m" if remaining_minutes > 0 else f"{hours}h"
            else:
                time_text = f"{estimated_minutes}m"
            
            count_label = QLabel(time_text)
            count_label.setStyleSheet(f"""
                font-size: 12px;
                color: {color};
                font-weight: 600;
                background-color: rgba(0, 0, 0, 0.05);
                border-radius: 8px;
                padding: 2px 6px;
            """)
            item_layout.addWidget(count_label)
            
            section_layout.addWidget(item_frame)
        
        return section
    
    def create_action_buttons(self, layout):
        """Create action buttons section"""
        buttons_layout = QHBoxLayout()
        buttons_layout.setSpacing(15)
        
        # Share button (placeholder)
        share_btn = QPushButton("📤 Export Report")
        share_btn.setStyleSheet("""
            QPushButton {
                padding: 12px 24px;
                font-size: 15px;
                font-weight: 500;
                border: 1px solid rgba(0, 122, 255, 0.3);
                border-radius: 12px;
                background-color: rgba(0, 122, 255, 0.05);
                color: #007aff;
            }
            QPushButton:hover {
                background-color: rgba(0, 122, 255, 0.1);
                border-color: rgba(0, 122, 255, 0.5);
            }
        """)
        share_btn.clicked.connect(self.export_report)
        buttons_layout.addWidget(share_btn)
        
        buttons_layout.addStretch()
        
        # Close button
        close_btn = QPushButton("🎉 Finish Session")
        close_btn.clicked.connect(self.finish_and_close)
        close_btn.setDefault(True)
        close_btn.setStyleSheet("""
            QPushButton {
                padding: 15px 30px;
                font-size: 16px;
                font-weight: 600;
                border: none;
                border-radius: 12px;
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #007aff, stop:1 #0056cc);
                color: white;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #0056cc, stop:1 #004499);
            }
            QPushButton:pressed {
                background: #004499;
            }
        """)
        buttons_layout.addWidget(close_btn)
        
        layout.addLayout(buttons_layout)
    
    def get_mode_display_name(self, mode):
        """Get display name for focus mode"""
        mode_names = {
            "productivity": "🏢 Productivity",
            "creativity": "🎨 Creativity", 
            "social_media_detox": "🧘 Social Media Detox"
        }
        return mode_names.get(mode, mode.title())
    
    def export_report(self):
        """Export session report (placeholder for future implementation)"""
        from PyQt5.QtWidgets import QMessageBox
        QMessageBox.information(self, "Export Report", 
                              "Report export feature will be available in a future update!")
    
    def finish_and_close(self):
        """Finish session and close application"""
        print("Final summary closed - performing cleanup and exit")
        
        # Properly cleanup with password manager before exit
        try:
            stop_focus_mode_with_password()
            print("Final cleanup completed successfully")
        except Exception as e:
            print(f"Error during final cleanup: {e}")
        
        # Close dialog and exit application
        self.accept()
        import sys
        sys.exit(0)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())

    
    def create_section_card(self, section, section_index):
        """Create a card showing section details and stats"""
        card = QFrame()
        card.setStyleSheet("""
            QFrame {
                background-color: #f8f9fa;
                border-radius: 12px;
                padding: 15px;
                margin: 5px 0px;
            }
        """)
        
        card_layout = QHBoxLayout(card)
        card_layout.setContentsMargins(15, 15, 15, 15)
        card_layout.setSpacing(15)
        
        # Mode indicator
        mode = section['mode']
        mode_indicator = QLabel()
        mode_indicator.setFixedSize(40, 40)
        color = self.mode_colors.get(mode, '#007aff')
        mode_indicator.setStyleSheet(f"""
            background-color: {color};
            border-radius: 20px;
        """)
        card_layout.addWidget(mode_indicator)
        
        # Section info
        info_layout = QVBoxLayout()
        info_layout.setSpacing(5)
        
        mode_name = mode.replace('_', ' ').title()
        name_label = QLabel(f"Section {index + 1}: {mode_name}")
        name_label.setStyleSheet("""
            font-size: 16px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        info_layout.addWidget(name_label)
        
        # Stats
        planned_duration = stats['planned_duration']
        actual_duration = stats['actual_duration']
        todos_completed = stats['todos_completed']
        todos_planned = stats['todos_planned']
        
        time_text = f"Time: {actual_duration:.0f}m"
        if actual_duration != planned_duration:
            time_text += f" (planned: {planned_duration:.0f}m)"
        
        time_label = QLabel(time_text)
        time_label.setStyleSheet("""
            font-size: 14px;
            color: #666;
        """)
        info_layout.addWidget(time_label)
        
        todos_text = f"Tasks: {todos_completed}/{todos_planned} completed"
        todos_label = QLabel(todos_text)
        todos_label.setStyleSheet("""
            font-size: 14px;
            color: #666;
        """)
        info_layout.addWidget(todos_label)
        
        # Show individual todos with mode-colored indicators
        section_todos = section.get('todos', [])
        if section_todos:
            for todo in section_todos:
                todo_container = QWidget()
                todo_layout = QHBoxLayout(todo_container)
                todo_layout.setContentsMargins(0, 2, 0, 2)
                todo_layout.setSpacing(8)
                
                # Mode color indicator
                todo_indicator = QLabel("●")
                todo_indicator.setStyleSheet(f"""
                    color: {color};
                    font-size: 12px;
                    margin-right: 4px;
                """)
                
                # Todo text
                todo_text = QLabel(todo.replace('• ', ''))
                todo_text.setWordWrap(True)
                todo_text.setStyleSheet("""
                    font-size: 12px;
                    color: #666;
                    line-height: 1.3;
                """)
                
                todo_layout.addWidget(todo_indicator)
                todo_layout.addWidget(todo_text)
                todo_layout.addStretch()
                
                info_layout.addWidget(todo_container)
        
        card_layout.addLayout(info_layout)
        
        # Completion percentage
        completion = (todos_completed / todos_planned * 100) if todos_planned > 0 else 100
        completion_label = QLabel(f"{completion:.0f}%")
        completion_label.setAlignment(Qt.AlignCenter)
        completion_label.setStyleSheet("""
            font-size: 18px;
            font-weight: 700;
            color: #30d158;
        """)
        card_layout.addWidget(completion_label)
        
        return card
    
    def create_final_timeline(self):
        """Create final timeline visualization"""
        container = QWidget()
        container.setFixedHeight(50)
        layout = QHBoxLayout(container)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(3)
        
        total_duration = sum(stats['actual_duration'] for stats in self.section_stats)
        
        for i, (section, stats) in enumerate(zip(self.session_structure, self.section_stats)):
            mode = section['mode']
            duration = stats['actual_duration']
            proportion = duration / total_duration if total_duration > 0 else 1 / len(self.section_structure)
            
            # Section bar
            section_bar = QWidget()
            section_bar.setFixedHeight(30)
            
            color = self.mode_colors.get(mode, '#007aff')
            section_bar.setStyleSheet(f"""
                background-color: {color};
                border-radius: 15px;
            """)
            
            # Set width based on proportion
            width = max(30, int(500 * proportion))
            section_bar.setFixedWidth(width)
            
            layout.addWidget(section_bar)
        
        return container
    
    def create_metric_card(self, title, value, color):
        """Create a metric display card"""
        card = QFrame()
        card.setStyleSheet(f"""
            QFrame {
                background-color: {color}15;
                border: 2px solid {color};
                border-radius: 10px;
                padding: 15px;
            }
        """)
        
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(10, 10, 10, 10)
        card_layout.setSpacing(5)
        
        value_label = QLabel(value)
        value_label.setAlignment(Qt.AlignCenter)
        value_label.setStyleSheet(f"""
            font-size: 24px;
            font-weight: 700;
            color: {color};
        """)
        card_layout.addWidget(value_label)
        
        title_label = QLabel(title)
        title_label.setAlignment(Qt.AlignCenter)
        title_label.setStyleSheet("""
            font-size: 12px;
            color: #666;
            font-weight: 500;
        """)
        card_layout.addWidget(title_label)
        
        return card
    
    def finish_and_close(self):
        """Finish session and close application"""
        print("Final summary closed - performing cleanup and exit")
        
        # Properly cleanup with password manager before exit
        try:
            stop_focus_mode_with_password()
            print("Final cleanup completed successfully")
        except Exception as e:
            print(f"Error during final cleanup: {e}")
        
        # Close dialog and exit application
        self.accept()
        import sys
        sys.exit(0)


class InteractiveTimeline(QWidget):
    """Interactive timeline widget with draggable dividers for adjusting session durations"""
    
    duration_changed = pyqtSignal(list)  # Emits new durations when changed
    
    def __init__(self, session_structure, total_duration, mode_colors, mode_names, parent=None):
        super().__init__(parent)
        self.session_structure = session_structure or []
        self.total_duration = total_duration
        self.mode_colors = mode_colors
        self.mode_names = mode_names
        self.timeline_width = 600
        self.timeline_height = 40
        self.divider_width = 8
        self.min_section_minutes = 0.5  # 30 seconds minimum
        
        # Track divider positions and dragging state
        self.divider_positions = []
        self.dragging_divider = None
        self.drag_start_x = 0
        
        self.calculate_initial_positions()
        self.setFixedSize(self.timeline_width, 80)
        self.setMouseTracking(True)
        
    def calculate_initial_positions(self):
        """Calculate initial divider positions based on section durations"""
        self.divider_positions = []
        if len(self.session_structure) <= 1:
            return
            
        current_x = 0
        for i, section in enumerate(self.session_structure[:-1]):  # All except last
            duration = section['duration_minutes']
            proportion = duration / self.total_duration if self.total_duration > 0 else 0
            section_width = int(self.timeline_width * proportion)
            current_x += section_width
            self.divider_positions.append(current_x)
    
    def paintEvent(self, event):
        """Paint the timeline with sections and dividers"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        if not self.session_structure:
            return
            
        # Draw rounded background first
        background_rect = QRect(0, 10, self.timeline_width, self.timeline_height)
        painter.setPen(Qt.NoPen)
        painter.setBrush(QBrush(QColor('#e5e5e7')))
        painter.drawRoundedRect(background_rect, self.timeline_height//2, self.timeline_height//2)
        
        # Draw sections with rounded corners
        current_x = 0
        for i, section in enumerate(self.session_structure):
            duration = section['duration_minutes']
            proportion = duration / self.total_duration if self.total_duration > 0 else 1
            section_width = int(self.timeline_width * proportion)
            
            # Section rectangle with rounded corners
            color = QColor(self.mode_colors.get(section['mode'], '#007aff'))
            painter.setBrush(QBrush(color))
            
            # Create rounded rect for section
            section_rect = QRect(current_x, 10, section_width, self.timeline_height)
            
            # Determine which corners to round based on position
            if i == 0 and i == len(self.session_structure) - 1:
                # Single section - round all corners
                painter.drawRoundedRect(section_rect, self.timeline_height//2, self.timeline_height//2)
            elif i == 0:
                # First section - round left corners only
                path = QPainterPath()
                path.moveTo(current_x + self.timeline_height//2, 10)
                path.arcTo(current_x, 10, self.timeline_height, self.timeline_height, 90, 180)
                path.lineTo(current_x + section_width, 10 + self.timeline_height)
                path.lineTo(current_x + section_width, 10)
                path.closeSubpath()
                painter.drawPath(path)
            elif i == len(self.session_structure) - 1:
                # Last section - round right corners only
                path = QPainterPath()
                path.moveTo(current_x, 10)
                path.lineTo(current_x + section_width - self.timeline_height//2, 10)
                path.arcTo(current_x + section_width - self.timeline_height, 10, self.timeline_height, self.timeline_height, 90, -180)
                path.lineTo(current_x, 10 + self.timeline_height)
                path.closeSubpath()
                painter.drawPath(path)
            else:
                # Middle section - no rounded corners
                painter.drawRect(section_rect)
            
            # Section label
            painter.setPen(QColor('white'))
            painter.setFont(QFont('SF Pro Display', 10, QFont.Medium))  # More Apple-like font
            text = f"{self.mode_names.get(section['mode'], section['mode'])}\n{duration:.1f}m"
            text_rect = QRect(current_x, 10, section_width, self.timeline_height)
            painter.drawText(text_rect, Qt.AlignCenter, text)
            
            current_x += section_width
        
        # Draw modern dividers with rounded appearance
        for i, pos in enumerate(self.divider_positions):
            divider_width = 6  # Slightly smaller for modern look
            divider_rect = QRect(pos - divider_width//2, 8, divider_width, self.timeline_height + 4)
            
            # Highlight if hovering or dragging
            if self.dragging_divider == i or self.get_divider_at_pos(self.mapFromGlobal(self.cursor().pos()).x()) == i:
                painter.setBrush(QBrush(QColor('#007aff')))
            else:
                painter.setBrush(QBrush(QColor('#ffffff')))
            
            painter.setPen(QPen(QColor('#d1d1d6'), 1))
            painter.drawRoundedRect(divider_rect, 3, 3)  # Rounded dividers
            
            # Modern handle indicators (3 dots)
            painter.setPen(Qt.NoPen)
            painter.setBrush(QBrush(QColor('#999999')))
            center_y = 10 + self.timeline_height//2
            for dot_offset in [-3, 0, 3]:
                painter.drawEllipse(pos - 1, center_y + dot_offset, 2, 2)
    
    def get_divider_at_pos(self, x):
        """Get divider index at mouse position, or None"""
        for i, pos in enumerate(self.divider_positions):
            if abs(x - pos) <= self.divider_width // 2:
                return i
        return None
    
    def mousePressEvent(self, event):
        """Handle mouse press for divider dragging"""
        if event.button() == Qt.LeftButton:
            divider = self.get_divider_at_pos(event.x())
            if divider is not None:
                self.dragging_divider = divider
                self.drag_start_x = event.x()
                self.setCursor(Qt.SizeHorCursor)
    
    def mouseMoveEvent(self, event):
        """Handle mouse move for divider dragging and cursor changes"""
        if self.dragging_divider is not None:
            # Dragging a divider
            new_pos = event.x()
            
            # Constrain position
            left_bound = self.divider_positions[self.dragging_divider - 1] + self.min_section_minutes * (self.timeline_width / self.total_duration) if self.dragging_divider > 0 else self.min_section_minutes * (self.timeline_width / self.total_duration)
            right_bound = self.divider_positions[self.dragging_divider + 1] - self.min_section_minutes * (self.timeline_width / self.total_duration) if self.dragging_divider < len(self.divider_positions) - 1 else self.timeline_width - self.min_section_minutes * (self.timeline_width / self.total_duration)
            
            new_pos = max(left_bound, min(right_bound, new_pos))
            self.divider_positions[self.dragging_divider] = new_pos
            
            # Update durations and emit signal
            self.update_durations_from_positions()
            self.update()
        else:
            # Change cursor when hovering over dividers
            if self.get_divider_at_pos(event.x()) is not None:
                self.setCursor(Qt.SizeHorCursor)
            else:
                self.setCursor(Qt.ArrowCursor)
    
    def mouseReleaseEvent(self, event):
        """Handle mouse release to stop dragging"""
        if event.button() == Qt.LeftButton and self.dragging_divider is not None:
            self.dragging_divider = None
            self.setCursor(Qt.ArrowCursor)
    
    def update_durations_from_positions(self):
        """Update section durations based on current divider positions"""
        if not self.session_structure:
            return
            
        new_durations = []
        positions = [0] + self.divider_positions + [self.timeline_width]
        
        for i in range(len(positions) - 1):
            section_width = positions[i + 1] - positions[i]
            proportion = section_width / self.timeline_width
            duration = max(self.min_section_minutes, proportion * self.total_duration)
            new_durations.append(round(duration, 1))
        
        # Update session structure
        for i, duration in enumerate(new_durations):
            if i < len(self.session_structure):
                self.session_structure[i]['duration_minutes'] = duration
        
        # Recalculate total (in case of rounding)
        self.total_duration = sum(new_durations)
        
        # Emit signal
        self.duration_changed.emit(new_durations)


class SessionVisualizationDialog(QDialog):
    def __init__(self, ai_analysis, final_goals, parent=None):
        super().__init__(parent)
        self.ai_analysis = ai_analysis
        self.final_goals = final_goals
        self.session_structure = ai_analysis.get('session_structure', []) if ai_analysis else []
        self.total_duration = ai_analysis.get('total_duration', 60) if ai_analysis else 60
        
        # Apple design color scheme for focus modes
        self.mode_colors = {
            "productivity": "#007aff",      # Apple Blue
            "creativity": "#30d158",        # Apple Green  
            "social_media_detox": "#ff9500" # Apple Orange
        }
        
        # Light variants for backgrounds
        self.mode_colors_light = {
            "productivity": "#e6f2ff",      # Light Blue
            "creativity": "#e6f7ed",        # Light Green
            "social_media_detox": "#fff2e6" # Light Orange
        }
        
        self.mode_names = {
            "productivity": "Productivity",
            "creativity": "Creativity",
            "social_media_detox": "Social Media Detox"
        }
        
        # Store original AI analysis for reset functionality
        self.original_ai_analysis = copy.deepcopy(ai_analysis) if ai_analysis else None
        
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Session Plan')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(700, 600)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # Add shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 80))
        shadow.setOffset(0, 10)
        self.setGraphicsEffect(shadow)
        
        self.center_window()
        
        self.setStyleSheet("""
            QDialog {
                background-color: white;
                border-radius: 20px;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(15)  # Reduced spacing to give more room to breakdown
        
        # Title
        title = QLabel("Your AI-Optimized Focus Session")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 22px;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 10px;
        """)
        layout.addWidget(title)
        
        # Total duration display
        duration_text = f"{self.total_duration} minutes total"
        if len(self.session_structure) > 1:
            duration_text += f" • {len(self.session_structure)} focus modes"
        
        duration_label = QLabel(duration_text)
        duration_label.setAlignment(Qt.AlignCenter)
        duration_label.setStyleSheet("""
            font-size: 16px;
            color: #86868b;
            margin-bottom: 10px;
        """)
        layout.addWidget(duration_label)
        
        # Visual timeline
        timeline_widget = self.create_timeline_widget()
        layout.addWidget(timeline_widget)
        
        # Session sections breakdown
        sections_widget = self.create_sections_widget()
        layout.addWidget(sections_widget)
        
        # Buttons
        button_layout = QHBoxLayout()
        
        reset_btn = QPushButton("Reset to AI Plan")
        reset_btn.clicked.connect(self.reset_to_original)
        reset_btn.setStyleSheet("""
            QPushButton {
                padding: 12px 20px;
                font-size: 14px;
                border: 2px solid #007aff;
                border-radius: 8px;
                background-color: white;
                color: #007aff;
            }
            QPushButton:hover { 
                background-color: #f0f8ff; 
            }
        """)
        
        start_btn = QPushButton("Start Focus Session")
        start_btn.clicked.connect(self.accept)
        start_btn.setDefault(True)
        start_btn.setStyleSheet("""
            QPushButton {
                padding: 12px 24px;
                font-size: 14px;
                font-weight: 600;
                border: none;
                border-radius: 8px;
                background-color: #007aff;
                color: white;
            }
            QPushButton:hover { background-color: #0056cc; }
        """)
        
        button_layout.addWidget(reset_btn)
        button_layout.addStretch()
        button_layout.addWidget(start_btn)
        layout.addLayout(button_layout)
        
        self.setLayout(layout)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def create_timeline_widget(self):
        """Create the interactive timeline with draggable dividers"""
        timeline_container = QWidget()
        timeline_container.setFixedHeight(120)  # Reduced height to give more space to breakdown
        timeline_layout = QVBoxLayout(timeline_container)
        timeline_layout.setSpacing(10)
        
        # Timeline title with edit hint
        header_layout = QHBoxLayout()
        timeline_title = QLabel("Session Timeline")
        timeline_title.setStyleSheet("""
            font-size: 16px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        
        edit_hint = QLabel("Drag dividers to adjust timing")
        edit_hint.setStyleSheet("""
            font-size: 12px;
            color: #86868b;
            font-style: italic;
        """)
        
        header_layout.addWidget(timeline_title)
        header_layout.addStretch()
        header_layout.addWidget(edit_hint)
        timeline_layout.addLayout(header_layout)
        
        # Create interactive timeline
        self.timeline_widget = InteractiveTimeline(self.session_structure, self.total_duration, self.mode_colors, self.mode_names)
        self.timeline_widget.duration_changed.connect(self.update_session_durations)
        timeline_layout.addWidget(self.timeline_widget)
        
        return timeline_container
    
    def update_session_durations(self, new_durations):
        """Update session structure when timeline is modified"""
        print(f"Timeline updated: {new_durations}")
        
        # Update session structure
        for i, duration in enumerate(new_durations):
            if i < len(self.session_structure):
                self.session_structure[i]['duration_minutes'] = duration
        
        # Recalculate total duration
        self.total_duration = sum(new_durations)
        
        # Update AI analysis total duration
        if self.ai_analysis:
            self.ai_analysis['total_duration'] = self.total_duration
        
        print(f"Updated total duration: {self.total_duration} minutes")
    
    def reset_to_original(self):
        """Reset session to original AI analysis"""
        if self.original_ai_analysis:
            # Restore original session structure
            self.ai_analysis = copy.deepcopy(self.original_ai_analysis)
            self.session_structure = self.ai_analysis.get('session_structure', [])
            self.total_duration = self.ai_analysis.get('total_duration', 60)
            
            # Recreate timeline widget
            self.timeline_widget.session_structure = self.session_structure
            self.timeline_widget.total_duration = self.total_duration
            self.timeline_widget.calculate_initial_positions()
            self.timeline_widget.update()
            
            print("Session reset to original AI plan")
    
    def create_sections_widget(self):
        """Create the sections breakdown showing todos by mode"""
        sections_container = QWidget()
        sections_layout = QVBoxLayout(sections_container)
        sections_layout.setSpacing(15)
        
        # Sections title
        sections_title = QLabel("Session Breakdown")
        sections_title.setStyleSheet("""
            font-size: 16px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        sections_layout.addWidget(sections_title)
        
        # Create scrollable area for sections
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll_area.setMaximumHeight(350)  # Increased from 250 to give more space
        scroll_area.setStyleSheet("""
            QScrollArea {
                border: none;
                background: transparent;
            }
        """)
        
        scroll_widget = QWidget()
        scroll_layout = QVBoxLayout(scroll_widget)
        scroll_layout.setSpacing(12)
        
        if not self.session_structure:
            # Fallback: show all goals in one section
            self.create_section_card(scroll_layout, "productivity", self.total_duration, self.final_goals)
        else:
            # Show each section
            for section in self.session_structure:
                mode = section['mode']
                duration = section['duration_minutes']
                todos = section.get('todos', [])
                self.create_section_card(scroll_layout, mode, duration, todos)
        
        scroll_area.setWidget(scroll_widget)
        sections_layout.addWidget(scroll_area)
        
        return sections_container
    
    def create_section_card(self, parent_layout, mode, duration, todos):
        """Create a card for each focus mode section"""
        card = QWidget()
        card.setStyleSheet(f"""
            QWidget {{
                background-color: #f8f9fa;
                border-left: 4px solid {self.mode_colors.get(mode, '#007aff')};
                border-radius: 8px;
                padding: 8px;
            }}
        """)
        
        card_layout = QVBoxLayout(card)
        card_layout.setSpacing(8)
        
        # Section header
        header_layout = QHBoxLayout()
        
        mode_name = self.mode_names.get(mode, mode.replace('_', ' ').title())
        mode_label = QLabel(mode_name)
        mode_label.setStyleSheet(f"""
            font-size: 14px;
            font-weight: 600;
            color: {self.mode_colors.get(mode, '#007aff')};
        """)
        
        duration_label = QLabel(f"{duration} minutes")
        duration_label.setStyleSheet("""
            font-size: 12px;
            color: #666;
        """)
        
        header_layout.addWidget(mode_label)
        header_layout.addStretch()
        header_layout.addWidget(duration_label)
        card_layout.addLayout(header_layout)
        
        # Todos list
        if todos:
            for todo in todos:
                todo_label = QLabel(f"• {todo}")
                todo_label.setWordWrap(True)
                todo_label.setStyleSheet("""
                    font-size: 13px;
                    color: #333;
                    padding-left: 12px;
                """)
                card_layout.addWidget(todo_label)
        else:
            no_todos_label = QLabel("No specific goals for this section")
            no_todos_label.setStyleSheet("""
                font-size: 12px;
                color: #999;
                font-style: italic;
                padding-left: 12px;
            """)
            card_layout.addWidget(no_todos_label)
        
        parent_layout.addWidget(card)
    
    def show_edit_options(self):
        """Show customization options (placeholder for now)"""
        from PyQt5.QtWidgets import QMessageBox
        QMessageBox.information(self, "Customization", 
                               "Session customization will be available in the next update!\n\n"
                               "For now, you can click 'Start Focus Session' to begin with the AI-optimized plan.")


class GoalsDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.goals_text = ""
        self.analyzed_goals = []
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Session Goals')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(500, 400)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # Add shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 80))
        shadow.setOffset(0, 10)
        self.setGraphicsEffect(shadow)
        
        self.center_window()
        
        self.setStyleSheet("""
            QDialog {
                background-color: white;
                border-radius: 20px;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)
        
        # Title
        title = QLabel("What do you want to accomplish?")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        layout.addWidget(title)
        
        # Subtitle
        subtitle = QLabel("List your goals for this focus session. AI will help prioritize them.")
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setWordWrap(True)
        subtitle.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
        """)
        layout.addWidget(subtitle)
        
        # Goals text area
        self.goals_input = QTextEdit()
        self.goals_input.setPlaceholderText("Type your goals as a list, sentence, paragraph, or however feels natural. AI will organize and prioritize them for you.\n\nExample: I need to finish my quarterly report which is due tomorrow, respond to important emails from clients, and plan next week's team meetings...")
        self.goals_input.setStyleSheet("""
            QTextEdit {
                padding: 12px;
                font-size: 14px;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: #fafafa;
            }
            QTextEdit:focus {
                border-color: #007aff;
                background-color: white;
            }
        """)
        layout.addWidget(self.goals_input)
        
        # Buttons
        button_layout = QHBoxLayout()
        
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        cancel_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
                font-size: 14px;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: white;
            }
            QPushButton:hover { background-color: #f5f5f7; }
        """)
        
        self.analyze_btn = QPushButton("AI Analyze & Continue")
        self.analyze_btn.clicked.connect(self.analyze_goals)
        self.analyze_btn.setDefault(True)
        self.analyze_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
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
        button_layout.addWidget(self.analyze_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def analyze_goals(self):
        self.goals_text = self.goals_input.toPlainText().strip()
        if not self.goals_text:
            return
        
        # Disable button and show loading
        self.analyze_btn.setText("AI Analyzing...")
        self.analyze_btn.setEnabled(False)
        
        # Call AI API
        try:
            result = self.get_ai_analysis(self.goals_text)
            if isinstance(result, tuple):
                self.analyzed_goals, self.used_ai = result
            else:
                self.analyzed_goals = result
                self.used_ai = False
            
            self.accept()
        except Exception as e:
            print(f"Error in AI analysis: {e}")
            # Fallback to simple parsing if AI fails
            self.analyzed_goals = self.fallback_analysis(self.goals_text)
            self.used_ai = False
            self.accept()
    
    def get_ai_analysis(self, goals_text):
        # Try Groq API (free tier: 1000 requests/day)
        groq_result = self.try_groq_api(goals_text)
        if groq_result:
            return groq_result, True
            
        # If API fails, use enhanced fallback
        print("AI API failed. Using enhanced fallback analysis.")
        return self.fallback_analysis(goals_text), False
    
    def try_groq_api(self, goals_text):
        """Try Groq API first (free tier)"""
        try:
            # Try to get Groq API key
            groq_key = self.load_groq_api_key()
            if not groq_key:
                print("No Groq API key found. Using fallback analysis...")
                return None
                
            url = "https://api.groq.com/openai/v1/chat/completions"
            
            prompt = f"""Analyze these focus session goals and return a clean, prioritized bullet list. 
Consider urgency, importance, and logical workflow order.

Goals: {goals_text}

Return ONLY a clean bullet list with • symbols, ordered by priority. Max 8 items. Be concise."""
            
            headers = {
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {groq_key}'
            }
            
            data = {
                "model": "llama-3.3-70b-versatile",  # Free model on Groq
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 300,
                "temperature": 0.3
            }
            
            import requests
            print("Trying Groq API...")
            response = requests.post(url, headers=headers, json=data, timeout=15)
            
            print(f"Groq API Response status: {response.status_code}")
            if response.status_code == 200:
                result = response.json()
                ai_response = result['choices'][0]['message']['content'].strip()
                print(f"Groq AI Response: {ai_response}")
                
                # Parse the AI response into a list
                lines = [line.strip() for line in ai_response.split('\n') if line.strip().startswith('•')]
                if lines:
                    print(f"Parsed {len(lines)} goals from Groq AI response")
                    return lines[:8]
                else:
                    print("No bullet points found in Groq response")
                    return None
            else:
                print(f"Groq API error: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            print(f"Groq API failed: {e}")
            return None
    
    
    def load_groq_api_key(self):
        """Load Groq API key from file or environment variable"""
        # First try to load from groq_api_key.txt file
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            key_file = os.path.join(script_dir, 'groq_api_key.txt')
            
            if os.path.exists(key_file):
                with open(key_file, 'r') as f:
                    api_key = f.read().strip()
                    # Check if it's not the placeholder text
                    if api_key and api_key != 'gsk-your-groq-api-key-here':
                        return api_key
        except Exception as e:
            print(f"Error reading Groq API key file: {e}")
        
        # Fallback to environment variable
        return os.environ.get('GROQ_API_KEY')
    
    
    def fallback_analysis(self, goals_text):
        """Enhanced fallback analysis that better organizes goals"""
        print("Using enhanced fallback analysis...")
        
        # Split text into sentences and clean them
        import re
        
        # Split by common delimiters
        sentences = re.split(r'[.!?;,\n]', goals_text)
        goals = []
        
        priority_keywords = ['urgent', 'asap', 'deadline', 'due', 'important', 'critical', 'priority']
        urgency_markers = ['today', 'tomorrow', 'this week', 'end of day', 'eod']
        
        processed_goals = []
        
        for sentence in sentences:
            sentence = sentence.strip()
            if len(sentence) < 5:  # Skip very short fragments
                continue
                
            # Remove common sentence starters
            sentence = re.sub(r'^(i need to|i want to|i should|i have to|need to|want to|should|have to)\s*', '', sentence, flags=re.IGNORECASE)
            
            # Capitalize first letter
            if sentence:
                sentence = sentence[0].upper() + sentence[1:]
                
                # Calculate priority score
                priority_score = 0
                text_lower = sentence.lower()
                
                # Check for priority keywords
                for keyword in priority_keywords:
                    if keyword in text_lower:
                        priority_score += 3
                        
                # Check for urgency markers
                for marker in urgency_markers:
                    if marker in text_lower:
                        priority_score += 2
                
                # Shorter, action-oriented goals get slight priority
                if len(sentence.split()) <= 8:
                    priority_score += 1
                    
                processed_goals.append((sentence, priority_score))
        
        # Sort by priority score (descending)
        processed_goals.sort(key=lambda x: x[1], reverse=True)
        
        # Format as bullet points
        for goal, score in processed_goals[:8]:
            goals.append(f"• {goal}")
        
        # If we still don't have enough goals, break down the original text more
        if len(goals) < 3:
            # Try splitting on "and" as well
            additional_goals = []
            for part in goals_text.split(' and '):
                part = part.strip().strip(',.')
                if part and len(part) > 10:
                    if not part.startswith('•'):
                        additional_goals.append(f"• {part.capitalize()}")
            
            goals.extend(additional_goals[:8-len(goals)])
        
        return goals[:8] if goals else [f"• {goals_text.strip()}"]

class GoalsReviewDialog(QDialog):
    def __init__(self, analyzed_goals, parent=None):
        super().__init__(parent)
        self.analyzed_goals = analyzed_goals
        self.approved = False
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Review Your Goals')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(500, 400)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # Add shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 80))
        shadow.setOffset(0, 10)
        self.setGraphicsEffect(shadow)
        
        self.center_window()
        
        self.setStyleSheet("""
            QDialog {
                background-color: white;
                border-radius: 20px;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)
        
        # Title
        title = QLabel("AI Organized Your Goals")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        layout.addWidget(title)
        
        # Subtitle - dynamic based on whether AI was used
        if hasattr(self, 'used_ai') and self.used_ai:
            subtitle_text = "Here's how AI prioritized your goals for the session:"
        else:
            subtitle_text = "Here are your organized and prioritized goals for the session:"
        
        subtitle = QLabel(subtitle_text)
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setWordWrap(True)
        subtitle.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
        """)
        layout.addWidget(subtitle)
        
        # Goals display
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
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
        
        goals_widget = QWidget()
        goals_layout = QVBoxLayout(goals_widget)
        goals_layout.setSpacing(8)
        goals_layout.setContentsMargins(15, 15, 15, 15)
        
        for goal in self.analyzed_goals:
            goal_label = QLabel(goal)
            goal_label.setWordWrap(True)
            goal_label.setStyleSheet("""
                font-size: 14px;
                color: #1d1d1f;
                padding: 8px 0px;
                line-height: 1.4;
            """)
            goals_layout.addWidget(goal_label)
        
        scroll.setWidget(goals_widget)
        layout.addWidget(scroll)
        
        # Buttons
        button_layout = QHBoxLayout()
        button_layout.setSpacing(12)
        
        back_btn = QPushButton("Revise Goals")
        back_btn.clicked.connect(self.reject)
        back_btn.setStyleSheet("""
            QPushButton {
                padding: 12px 20px;
                font-size: 14px;
                font-weight: 500;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: white;
                color: #1d1d1f;
            }
            QPushButton:hover { background-color: #f5f5f7; }
        """)
        
        continue_btn = QPushButton("Start Focus Session")
        continue_btn.clicked.connect(self.approve_goals)
        continue_btn.setDefault(True)
        continue_btn.setStyleSheet("""
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
        
        button_layout.addWidget(back_btn)
        button_layout.addWidget(continue_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def approve_goals(self):
        self.approved = True
        self.accept()

class PluginTaskDialog(QDialog):
    def __init__(self, current_goals, parent=None):
        super().__init__(parent)
        self.current_goals = current_goals
        self.final_goals = current_goals.copy()
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Additional Tasks')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(600, 500)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # Add shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 80))
        shadow.setOffset(0, 10)
        self.setGraphicsEffect(shadow)
        
        self.center_window()
        
        self.setStyleSheet("""
            QDialog {
                background-color: white;
                border-radius: 20px;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)
        
        # Title
        title = QLabel("Checking for Additional Tasks...")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        layout.addWidget(title)
        
        # Status label
        self.status_label = QLabel("Scanning for important tasks...")
        self.status_label.setAlignment(Qt.AlignCenter)
        self.status_label.setWordWrap(True)
        self.status_label.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
        """)
        layout.addWidget(self.status_label)
        
        # Tasks area (initially hidden)
        self.tasks_container = QWidget()
        self.tasks_layout = QVBoxLayout(self.tasks_container)
        self.tasks_layout.setSpacing(12)
        
        layout.addWidget(self.tasks_container)
        self.tasks_container.hide()
        
        # Buttons
        self.button_layout = QHBoxLayout()
        
        self.skip_btn = QPushButton("Skip")
        self.skip_btn.clicked.connect(self.skip_scan)
        self.skip_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
                font-size: 14px;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: white;
            }
            QPushButton:hover { background-color: #f5f5f7; }
        """)
        
        self.continue_btn = QPushButton("Continue")
        self.continue_btn.clicked.connect(self.accept)
        self.continue_btn.setDefault(True)
        self.continue_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 600;
                border: none;
                border-radius: 8px;
                background-color: #007aff;
                color: white;
            }
            QPushButton:hover { background-color: #0056cc; }
        """)
        self.continue_btn.hide()  # Initially hidden
        
        self.button_layout.addStretch()
        self.button_layout.addWidget(self.skip_btn)
        self.button_layout.addWidget(self.continue_btn)
        
        layout.addLayout(self.button_layout)
        self.setLayout(layout)
        
        # Start plugin task scanning after dialog is shown
        QTimer.singleShot(500, self.scan_for_tasks)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def scan_for_tasks(self):
        """Use plugin hooks to scan for additional tasks"""
        try:
            from plugin_system import plugin_manager
            
            # Call plugin hooks to get additional tasks - plugins return suggested tasks
            additional_tasks = plugin_manager.call_goals_analyzed_hooks(self.current_goals, "")
            
            # Check if any plugins added tasks
            if len(additional_tasks) > len(self.current_goals):
                # Some plugins added tasks
                new_tasks = additional_tasks[len(self.current_goals):]
                self.show_additional_tasks(new_tasks)
            else:
                # No additional tasks found
                self.show_no_additional_tasks()
                
        except Exception as e:
            print(f"Error scanning for additional tasks: {e}")
            self.show_no_additional_tasks()
    
    def show_additional_tasks(self, new_tasks):
        """Show additional tasks found by plugins"""
        self.status_label.setText("Found additional tasks that may be important:")
        
        # Create checkboxes for each additional task
        self.task_checkboxes = []
        for task in new_tasks:
            checkbox = QCheckBox()
            checkbox.setChecked(True)  # Default to checked
            checkbox.setText(task)
            checkbox.setStyleSheet("""
                QCheckBox {
                    font-size: 14px;
                    color: #4a4a4a;
                    spacing: 12px;
                    padding: 8px 0px;
                    font-weight: 500;
                    line-height: 1.4;
                }
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
            self.tasks_layout.addWidget(checkbox)
            self.task_checkboxes.append((checkbox, task))
        
        # Add instruction
        instruction = QLabel("Select which tasks to add to your focus session:")
        instruction.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
            margin-bottom: 10px;
        """)
        self.tasks_layout.insertWidget(0, instruction)
        
        self.tasks_container.show()
        self.continue_btn.setText("Add Selected & Continue")
        self.continue_btn.show()
        self.skip_btn.setText("Skip All")
    
    def show_no_additional_tasks(self):
        self.status_label.setText("No additional tasks found.")
        self.continue_btn.setText("Continue")
        self.continue_btn.show()
    
    def skip_scan(self):
        """Skip task scanning and continue with original goals"""
        self.final_goals = self.current_goals.copy()
        self.accept()
    
    def accept(self):
        """Accept and add selected tasks to goals"""
        if hasattr(self, 'task_checkboxes'):
            # Add selected tasks to the beginning of goals list
            selected_tasks = []
            for checkbox, task in self.task_checkboxes:
                if checkbox.isChecked():
                    selected_tasks.append(task)
            
            # Combine additional tasks with existing goals
            self.final_goals = selected_tasks + self.current_goals
        else:
            # If no checkboxes (no additional tasks found), keep original goals
            self.final_goals = self.current_goals.copy()
        
        super().accept()

class FinalGoalsDialog(QDialog):
    def __init__(self, final_goals, parent=None):
        super().__init__(parent)
        self.final_goals = final_goals
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Updated Focus Goals')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(500, 400)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # Add shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 80))
        shadow.setOffset(0, 10)
        self.setGraphicsEffect(shadow)
        
        self.center_window()
        
        self.setStyleSheet("""
            QDialog {
                background-color: white;
                border-radius: 20px;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)
        
        # Title
        title = QLabel("Your Complete Focus Plan")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        layout.addWidget(title)
        
        # Subtitle
        subtitle = QLabel("Here are your goals including important email tasks:")
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setWordWrap(True)
        subtitle.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
        """)
        layout.addWidget(subtitle)
        
        # Goals display
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
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
        
        goals_widget = QWidget()
        goals_layout = QVBoxLayout(goals_widget)
        goals_layout.setSpacing(8)
        goals_layout.setContentsMargins(15, 15, 15, 15)
        
        for goal in self.final_goals:
            goal_label = QLabel(goal)
            goal_label.setWordWrap(True)
            goal_label.setStyleSheet("""
                font-size: 14px;
                color: #1d1d1f;
                padding: 8px 0px;
                line-height: 1.4;
            """)
            goals_layout.addWidget(goal_label)
        
        scroll.setWidget(goals_widget)
        layout.addWidget(scroll)
        
        # Buttons
        button_layout = QHBoxLayout()
        button_layout.setSpacing(12)
        
        back_btn = QPushButton("Revise Goals")
        back_btn.clicked.connect(self.reject)
        back_btn.setStyleSheet("""
            QPushButton {
                padding: 12px 20px;
                font-size: 14px;
                font-weight: 500;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: white;
                color: #1d1d1f;
            }
            QPushButton:hover { background-color: #f5f5f7; }
        """)
        
        continue_btn = QPushButton("Start Focus Session")
        continue_btn.clicked.connect(self.accept)
        continue_btn.setDefault(True)
        continue_btn.setStyleSheet("""
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
        
        button_layout.addWidget(back_btn)
        button_layout.addWidget(continue_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())

class SegmentedProgressBar(QWidget):
    """Segmented progress bar for multi-section sessions"""
    
    def __init__(self, session_structure, current_section_index, mode_colors, parent=None):
        super().__init__(parent)
        self.session_structure = session_structure
        self.current_section_index = current_section_index
        self.mode_colors = mode_colors
        self.current_progress = 0.0  # Progress within current section (0-100)
        
        # Calculate section proportions
        total_duration = sum(section['duration_minutes'] for section in session_structure)
        self.section_proportions = []
        for section in session_structure:
            proportion = section['duration_minutes'] / total_duration if total_duration > 0 else 1.0 / len(session_structure)
            self.section_proportions.append(proportion)
    
    def set_progress(self, progress_percent):
        """Set progress within current section (0-100)"""
        self.current_progress = progress_percent
        self.update()
    
    def paintEvent(self, event):
        """Paint the modern segmented progress bar with Apple-style rounded corners"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        width = self.width()
        height = self.height()
        radius = height // 2
        
        # Draw rounded background
        painter.setPen(Qt.NoPen)
        painter.setBrush(QBrush(QColor('#e5e5e7')))
        painter.drawRoundedRect(0, 0, width, height, radius, radius)
        
        # Create clipping path for rounded corners
        clipPath = QPainterPath()
        clipPath.addRoundedRect(0, 0, width, height, radius, radius)
        painter.setClipPath(clipPath)
        
        current_x = 0
        for i, (section, proportion) in enumerate(zip(self.session_structure, self.section_proportions)):
            mode = section['mode']
            section_width = int(width * proportion)
            
            # Get color for this section
            base_color = self.mode_colors.get(mode, '#007aff')
            color = QColor(base_color)
            
            # Set opacity based on completion status
            if i < self.current_section_index:
                # Completed sections - full opacity
                color.setAlpha(255)
                fill_width = section_width
            elif i == self.current_section_index:
                # Current section - fill based on progress
                color.setAlpha(255)
                fill_width = int(section_width * (self.current_progress / 100.0))
                
                # Draw unfilled part of current section with low opacity
                if fill_width < section_width:
                    unfilled_color = QColor(base_color)
                    unfilled_color.setAlpha(60)  # More subtle unfilled sections
                    painter.setBrush(QBrush(unfilled_color))
                    painter.drawRect(current_x + fill_width, 0, section_width - fill_width, height)
            else:
                # Future sections - low opacity, no fill
                color.setAlpha(60)  # More subtle future sections
                fill_width = 0
                painter.setBrush(QBrush(color))
                painter.drawRect(current_x, 0, section_width, height)
            
            # Draw filled portion with full opacity
            if fill_width > 0:
                painter.setBrush(QBrush(color))
                painter.drawRect(current_x, 0, fill_width, height)
            
            current_x += section_width


class ProgressPopup(QWidget):
    def __init__(self, session_duration, goals, popup_interval=1, parent_launcher=None, mode=None, plugins_already_triggered=False, session_structure=None, current_section_index=0):
        super().__init__()
        self.session_duration = session_duration  # in minutes
        self.goals = goals
        self.popup_interval = popup_interval  # in minutes
        self.parent_launcher = parent_launcher  # Reference to FocusLauncher
        self.mode = mode  # Focus mode for this session
        self.plugins_already_triggered = plugins_already_triggered  # Flag to prevent duplicate plugin calls
        self.ai_notification_sent = False  # Flag to send AI notification only once
        
        # Multi-section support
        self.session_structure = session_structure or []
        self.current_section_index = current_section_index
        self.is_multi_section = len(self.session_structure) > 1
        
        # Mode colors for multi-section display
        self.mode_colors = {
            "productivity": "#007aff",      # Apple Blue
            "creativity": "#30d158",        # Apple Green  
            "social_media_detox": "#ff9500" # Apple Orange
        }
        
        print(f"DEBUG: ProgressPopup initialized with interval: {popup_interval} minutes, mode: {mode}, multi-section: {self.is_multi_section}")
        self.start_time = datetime.now()
        self.completed_goals = set()
        self.app_usage = {}
        self.current_app = ""
        self.website_usage = {}
        self.last_browser_check = self.start_time
        
        # Clear browser tabs log for fresh session tracking
        self.clear_browser_tabs_log()
        
        self.init_ui()
        self.setup_system_tray()
        self.setup_timers()
        
        # Initialize AI Assistant
        self.ai_assistant_window = None
        self.setup_ai_assistant()
    
    def init_ui(self):
        self.setWindowTitle('Focus Session')
        self.setWindowIcon(get_app_icon())
        # Dynamic height based on number of goals
        base_height = 360
        num_goals = min(len(self.goals), 3) if self.goals else 0
        if num_goals > 0:
            goal_height = num_goals * 40 + 80  # Space per goal + titles/margins
            total_height = base_height + goal_height
        else:
            total_height = base_height
        
        self.setFixedSize(580, min(total_height, 500))  # Made wider to prevent button cutoff
        self.setWindowFlags(Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        
        
        self.center_window()
        
        self.setStyleSheet("""
            ProgressPopup {
                background-color: transparent;
            }
        """)
        
        # Create main container without margins
        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # Create light-colored content container
        content_container = QFrame()
        content_container.setStyleSheet("""
            QFrame {
                background-color: white;
                border-radius: 24px;
                padding: 0px;
            }
        """)
        
        # Add shadow effect to content container
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(40)
        shadow.setColor(QColor(0, 0, 0, 150))
        shadow.setOffset(0, 20)
        content_container.setGraphicsEffect(shadow)
        
        content_layout = QVBoxLayout(content_container)
        content_layout.setContentsMargins(25, 25, 25, 25)  # Reduced margins to prevent clipping
        content_layout.setSpacing(15)  # Reduced spacing to prevent clipping
        
        # Header section
        header_layout = QVBoxLayout()
        header_layout.setSpacing(8)
        
        # Title with better contrast
        self.title_label = QLabel("Focus Session Active")
        self.title_label.setAlignment(Qt.AlignCenter)
        self.title_label.setStyleSheet("""
            font-size: 22px;
            font-weight: 700;
            color: #1d1d1f;
        """)
        header_layout.addWidget(self.title_label)
        
        # Time info with better readability
        self.time_label = QLabel("")
        self.time_label.setAlignment(Qt.AlignCenter)
        self.time_label.setStyleSheet("""
            font-size: 18px;
            color: #007aff;
            font-weight: 600;
        """)
        header_layout.addWidget(self.time_label)
        
        content_layout.addLayout(header_layout)
        
        # Progress section
        progress_layout = QVBoxLayout()
        progress_layout.setSpacing(8)  # Reduced spacing to prevent clipping
        
        # Encouraging message instead of large percentage
        self.encouraging_label = QLabel("Let's make some progress together!")
        self.encouraging_label.setAlignment(Qt.AlignCenter)
        self.encouraging_label.setWordWrap(True)
        self.encouraging_label.setStyleSheet("""
            font-size: 18px;
            font-weight: 500;
            color: #4a4a4a;
            margin: 8px 0px;
            line-height: 1.3;
        """)
        progress_layout.addWidget(self.encouraging_label)
        
        # Segmented progress bar for multi-section or regular progress bar for single section
        if self.is_multi_section:
            self.segmented_progress = SegmentedProgressBar(
                self.session_structure, 
                self.current_section_index,
                self.mode_colors
            )
            self.segmented_progress.setFixedHeight(32)
            progress_layout.addWidget(self.segmented_progress)
            self.progress_bar = None  # No regular progress bar for multi-section
        else:
            # Regular progress bar for single sessions
            self.progress_bar = QProgressBar()
            self.progress_bar.setFixedHeight(32)
            self.progress_bar.setFormat("%p%")
            self.progress_bar.setStyleSheet("""
                QProgressBar {
                    border: 0px;
                    border-radius: 16px;
                    background-color: #e5e5e7;
                    text-align: center;
                    color: white;
                    font-weight: 600;
                    font-size: 14px;
                    outline: none;
                }
                QProgressBar::chunk {
                    border: 0px;
                    border-radius: 16px;
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                        stop:0 #007aff, stop:1 #0056cc);
                    outline: none;
                }
            """)
            
            # Add animation for progress bar
            from PyQt5.QtCore import QPropertyAnimation, QEasingCurve
            self.progress_animation = QPropertyAnimation(self.progress_bar, b"value")
            self.progress_animation.setDuration(800)
            self.progress_animation.setEasingCurve(QEasingCurve.OutCubic)
            progress_layout.addWidget(self.progress_bar)
            self.segmented_progress = None
        
        content_layout.addLayout(progress_layout)
        
        # Remove separate multi-section progress - now integrated into main progress bar
        
        # Goals section (only show if goals exist and it's not the first popup)
        self.goals_container = QScrollArea()
        self.goals_container.setWidgetResizable(True)
        self.goals_container.setMaximumHeight(200)  # Limit height to make it scrollable
        self.goals_container.setStyleSheet("""
            QScrollArea {
                border: none;
                background-color: transparent;
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
        
        # Create the actual goals widget that will be scrolled
        goals_widget = QWidget()
        self.goals_layout = QVBoxLayout(goals_widget)
        # Dynamic spacing based on number of goals
        num_goals = min(len(self.goals), 8) if self.goals else 0  # Show up to 8 goals
        dynamic_spacing = max(8, 20 - (num_goals * 2))  # More goals = less spacing
        self.goals_layout.setSpacing(dynamic_spacing)
        self.goals_layout.setContentsMargins(0, 10, 0, 10)
        
        if self.goals:
            goals_title = QLabel("Quick Check-in:")
            goals_title.setStyleSheet("""
                font-size: 16px;
                font-weight: 700;
                color: #1d1d1f;
                margin-bottom: 16px;
                margin-top: 8px;
            """)
            self.goals_layout.addWidget(goals_title)
            
            # Show all goals grouped by section if multi-section, otherwise show all
            self.goal_checkboxes = []
            
            if self.is_multi_section and self.session_structure:
                # Group todos by section with mode indicators
                for section_idx, section in enumerate(self.session_structure):
                    section_todos = section.get('todos', [])
                    if not section_todos:
                        continue
                    
                    mode = section['mode']
                    mode_name = self.get_mode_display_name(mode)
                    mode_color = self.mode_colors.get(mode, "#007aff")
                    
                    # Current vs other section styling
                    is_current_section = section_idx == self.current_section_index
                    
                    # Section header with mode indicator
                    section_header = QWidget()
                    section_layout = QHBoxLayout(section_header)
                    section_layout.setContentsMargins(0, 8, 0, 4)
                    section_layout.setSpacing(8)
                    
                    # Mode color indicator
                    mode_indicator = QLabel("●")
                    mode_indicator.setStyleSheet(f"""
                        font-size: 16px;
                        color: {mode_color};
                        font-weight: bold;
                    """)
                    
                    # Section title
                    section_title = QLabel(f"{mode_name}")
                    section_title.setStyleSheet(f"""
                        font-size: 14px;
                        font-weight: 600;
                        color: {'#1d1d1f' if is_current_section else '#86868b'};
                        margin-bottom: 2px;
                    """)
                    
                    section_layout.addWidget(mode_indicator)
                    section_layout.addWidget(section_title)
                    section_layout.addStretch()
                    
                    self.goals_layout.addWidget(section_header)
                    
                    # Add todos for this section
                    for todo in section_todos:
                        checkbox = QCheckBox(todo)
                        
                        # Style based on current vs other sections
                        if is_current_section:
                            checkbox_style = f"""
                                QCheckBox {{
                                    font-size: 14px;
                                    color: #1d1d1f;
                                    spacing: 12px;
                                    padding: 6px 0px 6px 20px;
                                    font-weight: 500;
                                    line-height: 1.4;
                                    margin-bottom: 2px;
                                }}
                                QCheckBox::indicator {{
                                    width: 18px;
                                    height: 18px;
                                    border-radius: 9px;
                                    border: 2px solid {mode_color};
                                    background-color: white;
                                    margin-right: 8px;
                                }}
                                QCheckBox::indicator:checked {{
                                    background-color: {mode_color};
                                    border-color: {mode_color};
                                }}
                            """
                        else:
                            checkbox_style = """
                                QCheckBox {
                                    font-size: 13px;
                                    color: #86868b;
                                    spacing: 12px;
                                    padding: 4px 0px 4px 20px;
                                    font-weight: 400;
                                    line-height: 1.3;
                                    margin-bottom: 1px;
                                }
                                QCheckBox::indicator {
                                    width: 16px;
                                    height: 16px;
                                    border-radius: 8px;
                                    border: 2px solid #d1d1d6;
                                    background-color: white;
                                    margin-right: 8px;
                                }
                                QCheckBox::indicator:checked {
                                    background-color: #d1d1d6;
                                    border-color: #d1d1d6;
                                }
                            """
                        
                        checkbox.setStyleSheet(checkbox_style)
                        checkbox.stateChanged.connect(self.goal_checked)
                        self.goals_layout.addWidget(checkbox)
                        self.goal_checkboxes.append(checkbox)
                    
                    # Add spacing after each section
                    if section_idx < len(self.session_structure) - 1:
                        spacer = QLabel()
                        spacer.setFixedHeight(8)
                        self.goals_layout.addWidget(spacer)
            else:
                # Fallback: show all goals without grouping
                for goal in self.goals:
                    checkbox = QCheckBox(goal)
                    checkbox.setStyleSheet("""
                        QCheckBox {
                            font-size: 14px;
                            color: #4a4a4a;
                            spacing: 12px;
                            padding: 8px 0px;
                            font-weight: 500;
                            line-height: 1.4;
                            margin-bottom: 2px;
                        }
                        QCheckBox::indicator {
                            width: 18px;
                            height: 18px;
                            border-radius: 9px;
                            border: 2px solid #d1d1d6;
                            background-color: white;
                            margin-right: 8px;
                        }
                        QCheckBox::indicator:checked {
                            background-color: #007aff;
                            border-color: #007aff;
                        }
                    """)
                    checkbox.stateChanged.connect(self.goal_checked)
                    self.goals_layout.addWidget(checkbox)
                    self.goal_checkboxes.append(checkbox)
        
        # Set the goals widget inside the scroll area
        self.goals_container.setWidget(goals_widget)
        
        content_layout.addWidget(self.goals_container)
        
        # Buttons
        button_layout = QHBoxLayout()
        button_layout.setSpacing(12)
        
        # Stop/End button (text depends on multi-section vs single)
        if self.is_multi_section:
            stop_btn = QPushButton("End Session")
            stop_btn.setToolTip("End the entire multi-section session")
        else:
            stop_btn = QPushButton("Stop Focus Mode")
        
        stop_btn.clicked.connect(self.stop_focus_mode)
        stop_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 500;
                border: 1px solid #d1d1d6;
                border-radius: 10px;
                background-color: white;
                color: #1d1d1f;
            }
            QPushButton:hover { 
                background-color: #f5f5f7; 
            }
            QPushButton:pressed {
                background-color: #e5e5e7;
            }
        """)
        button_layout.addWidget(stop_btn)
        
        # Early completion button (only for multi-section)
        if self.is_multi_section and self.current_section_index < len(self.session_structure) - 1:
            complete_btn = QPushButton("Complete Section")
            complete_btn.clicked.connect(self.complete_section_early)
            complete_btn.setToolTip("Finish this section early and move to the next one")
            complete_btn.setStyleSheet("""
                QPushButton {
                    padding: 10px 20px;
                    font-size: 14px;
                    font-weight: 500;
                    border: 1px solid #ff9500;
                    border-radius: 10px;
                    background-color: white;
                    color: #ff9500;
                }
                QPushButton:hover { 
                    background-color: #fff8f0; 
                }
                QPushButton:pressed {
                    background-color: #ffede0;
                }
            """)
            button_layout.addWidget(complete_btn)
        
        # Agent button
        agent_btn = QPushButton("Agent")
        agent_btn.clicked.connect(self.show_ai_assistant)
        agent_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 500;
                border: 1px solid #34c759;
                border-radius: 10px;
                background-color: white;
                color: #34c759;
            }
            QPushButton:hover { 
                background-color: #f0f9f0; 
            }
            QPushButton:pressed {
                background-color: #e5f3e5;
            }
        """)
        button_layout.addWidget(agent_btn)
        
        # Keep Focusing button (text depends on context)
        if self.is_multi_section:
            close_btn = QPushButton("Continue Section")
        else:
            close_btn = QPushButton("Keep Focusing")
            
        close_btn.clicked.connect(self.continue_session)
        close_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 600;
                border: none;
                border-radius: 10px;
                background-color: #007aff;
                color: white;
            }
            QPushButton:hover { 
                background-color: #0056cc; 
            }
            QPushButton:pressed {
                background-color: #004499;
            }
        """)
        button_layout.addWidget(close_btn)
        
        content_layout.addLayout(button_layout)
        
        # Add content container to main layout
        main_layout.addWidget(content_container)
        
        self.setLayout(main_layout)
    
    # Checkbox API methods for plugins
    def get_checklist_progress_percentage(self) -> float:
        """Get the current checklist completion percentage (0-100)"""
        if not self.goals or not hasattr(self, 'goal_checkboxes'):
            return 0.0
        
        completed_count = len(self.completed_goals)
        total_count = len(self.goals)
        return (completed_count / total_count * 100) if total_count > 0 else 0.0
    
    def get_completed_checklist_items(self) -> List[str]:
        """Get list of completed checklist items"""
        return list(self.completed_goals)
    
    def get_all_checklist_items(self) -> List[str]:
        """Get list of all checklist items"""
        return self.goals.copy() if self.goals else []
    
    def set_checklist_item_checked(self, item_text: str, checked: bool) -> bool:
        """Set a checklist item as checked/unchecked. Returns True if successful."""
        if not hasattr(self, 'goal_checkboxes'):
            return False
        
        # Find the checkbox for this item
        for checkbox in self.goal_checkboxes:
            if checkbox.text() == item_text:
                checkbox.setChecked(checked)
                return True
        
        return False
    
    def add_checklist_item(self, item_text: str) -> bool:
        """Add a new item to the checklist. Returns True if successful."""
        print(f"DEBUG: add_checklist_item called with: '{item_text}'")
        if not hasattr(self, 'goals_layout') or not hasattr(self, 'goal_checkboxes'):
            print("DEBUG: Missing goals_layout or goal_checkboxes")
            return False
        
        # Format task with bullet point if it doesn't have one
        formatted_task = item_text if item_text.startswith('•') else f"• {item_text}"
        
        # Add to goals list
        self.goals.append(formatted_task)
        
        try:
            from PyQt5.QtWidgets import QCheckBox
            checkbox = QCheckBox(formatted_task)
            checkbox.setStyleSheet("""
                QCheckBox {
                    font-size: 14px;
                    color: #1d1d1f;
                    padding: 8px 12px;
                    background: rgba(255, 255, 255, 0.8);
                    border-radius: 8px;
                    margin: 2px 0;
                }
                QCheckBox::indicator {
                    width: 16px;
                    height: 16px;
                    margin-right: 8px;
                }
                QCheckBox::indicator:unchecked {
                    border: 2px solid #d1d1d6;
                    border-radius: 4px;
                    background: white;
                }
                QCheckBox::indicator:checked {
                    border: 2px solid #007aff;
                    border-radius: 4px;
                    background: #007aff;
                    image: url(data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIiIGhlaWdodD0iMTIiIHZpZXdCb3g9IjAgMCAxMiAxMiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEwIDNMNC41IDguNUwyIDYiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+Cjwvc3ZnPgo=);
                }
            """)
            checkbox.stateChanged.connect(self.goal_checked)
            
            # Insert before the last item (stretch) in the layout
            insert_index = self.goals_layout.count() - 1
            self.goals_layout.insertWidget(insert_index, checkbox)
            self.goal_checkboxes.append(checkbox)
            
            return True
        except Exception as e:
            print(f"Error adding checkbox to UI: {e}")
            return False
    
    def get_mode_display_name(self, mode):
        """Get user-friendly display name for focus mode"""
        mode_names = {
            "productivity": "Productivity",
            "creativity": "Creativity", 
            "social_media_detox": "Social Media Detox"
        }
        return mode_names.get(mode, mode.title())
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    # Removed create_multi_section_progress method - now using integrated segmented progress bar
    
    def setup_timers(self):
        # Progress update timer (every second)
        self.progress_timer = QTimer()
        self.progress_timer.timeout.connect(self.update_progress)
        self.progress_timer.start(1000)
        
        # Popup display timer
        self.popup_timer = QTimer()
        self.popup_timer.timeout.connect(self.show_popup)
        timer_ms = self.popup_interval * 60 * 1000
        print(f"DEBUG: Starting popup timer with {timer_ms}ms ({self.popup_interval} minutes)")
        self.popup_timer.start(timer_ms)  # Convert to milliseconds
        
        # App tracking timer
        self.app_timer = QTimer()
        self.app_timer.timeout.connect(self.track_app_usage)
        self.app_timer.timeout.connect(self.track_website_usage)
        self.app_timer.start(5000)  # Every 5 seconds
        
        # Call session start hooks (only if not already triggered during video)
        if not self.plugins_already_triggered:
            try:
                from plugin_system import plugin_manager
                session_data = {
                    'mode': self.mode,
                    'duration': self.session_duration,
                    'goals': self.goals,
                    'start_time': self.start_time,
                    'trigger_point': 'progress_popup'
                }
                plugin_manager.call_session_start_hooks(session_data)
                print(f"Triggered session start plugins from progress popup for {self.mode}")
            except Exception as e:
                print(f"Plugin session start hook error: {e}")
        else:
            print(f"Skipping plugin triggers - already triggered during video for {self.mode}")
        
        # Initial popup
        self.show_popup()
    
    def setup_system_tray(self):
        """Setup enhanced system tray icon with section management features"""
        # Check if system tray is available
        if not QSystemTrayIcon.isSystemTrayAvailable():
            print("System tray not available on this system")
            return
        
        # Create tray icon
        self.tray_icon = QSystemTrayIcon(self)
        
        # Try to load icon from file, fall back to programmatic icon
        script_dir = os.path.dirname(os.path.abspath(__file__))
        icon_path = os.path.join(script_dir, 'tray_icon.png')
        
        if os.path.exists(icon_path):
            # Use custom icon file with template mode for automatic dark/light adaptation
            icon = QIcon(icon_path)
            icon.setIsMask(True)
            self.tray_icon.setIcon(icon)
        else:
            # Create dynamic icon that shows current section progress
            self.update_tray_icon()
        
        # Initialize enhanced context menu
        self.setup_enhanced_tray_menu()
        
        # Connect click to show/hide
        self.tray_icon.activated.connect(self.tray_icon_clicked)
        
        # Show the tray icon
        self.tray_icon.show()
        
        # Track visibility state
        self.is_visible = True
    
    def update_tray_icon(self):
        """Update tray icon to show current session progress"""
        icon_pixmap = QPixmap(16, 16)
        icon_pixmap.fill(Qt.transparent)
        
        painter = QPainter(icon_pixmap)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Draw progress ring based on current section
        if hasattr(self, 'session_manager') and self.session_manager:
            progress = self.session_manager.get_overall_progress()
            current_section = self.session_manager.current_section_index
            
            # Get current mode color
            if (hasattr(self.session_manager, 'session_structure') and 
                self.session_manager.session_structure and 
                current_section < len(self.session_manager.session_structure)):
                
                mode = self.session_manager.session_structure[current_section]['mode']
                mode_colors = {
                    "productivity": Qt.blue,
                    "creativity": Qt.green,
                    "social_media_detox": Qt.yellow
                }
                color = mode_colors.get(mode, Qt.gray)
            else:
                color = Qt.gray
            
            # Draw background circle
            painter.setPen(QPen(Qt.black, 1))
            painter.setBrush(Qt.NoBrush)
            painter.drawEllipse(1, 1, 14, 14)
            
            # Draw progress arc
            painter.setPen(QPen(color, 2))
            start_angle = 90 * 16  # Start at top
            span_angle = -int(360 * 16 * progress)  # Clockwise
            painter.drawArc(2, 2, 12, 12, start_angle, span_angle)
            
        else:
            # Default focus icon
            painter.setBrush(QBrush(Qt.black))
            painter.setPen(Qt.NoPen)
            painter.drawEllipse(2, 2, 12, 12)
        
        painter.end()
        
        # Use template mode for automatic color adaptation
        icon = QIcon(icon_pixmap)
        icon.setIsMask(True)
        self.tray_icon.setIcon(icon)
    
    def setup_enhanced_tray_menu(self):
        """Create enhanced context menu with section management features"""
        self.tray_menu = QMenu()
        
        # Session overview section
        if hasattr(self, 'session_manager') and self.session_manager:
            # Current section info
            current_section = self.session_manager.current_section_index
            if (hasattr(self.session_manager, 'session_structure') and 
                self.session_manager.session_structure and 
                current_section < len(self.session_manager.session_structure)):
                
                section = self.session_manager.session_structure[current_section]
                mode_name = self.get_mode_display_name(section['mode'])
                
                # Current section header
                section_header = QAction(f"{mode_name} (Section {current_section + 1})", self)
                section_header.setEnabled(False)  # Make it a header
                self.tray_menu.addAction(section_header)
                
                # Quick section actions
                if current_section > 0:
                    prev_action = QAction("Previous Section", self)
                    prev_action.triggered.connect(lambda: self.jump_to_section(current_section - 1))
                    self.tray_menu.addAction(prev_action)
                
                if current_section < len(self.session_manager.session_structure) - 1:
                    next_action = QAction("Next Section", self)
                    next_action.triggered.connect(lambda: self.jump_to_section(current_section + 1))
                    self.tray_menu.addAction(next_action)
                
                complete_section_action = QAction("Complete Current Section", self)
                complete_section_action.triggered.connect(self.complete_current_section)
                self.tray_menu.addAction(complete_section_action)
                
                self.tray_menu.addSeparator()
        
        # Standard actions
        self.show_hide_action = QAction("Show Progress", self)
        self.show_hide_action.triggered.connect(self.toggle_visibility)
        self.tray_menu.addAction(self.show_hide_action)
        
        # AI Assistant action with enhanced features
        ai_action = QAction("AI Agent", self)
        ai_action.triggered.connect(self.show_ai_assistant)
        self.tray_menu.addAction(ai_action)
        
        # Quick focus actions
        focus_submenu = self.tray_menu.addMenu("Quick Focus")
        
        extend_action = QAction("Extend Current Section (+15min)", self)
        extend_action.triggered.connect(lambda: self.extend_current_section(15))
        focus_submenu.addAction(extend_action)
        
        reduce_action = QAction("Reduce Current Section (-5min)", self)
        reduce_action.triggered.connect(lambda: self.reduce_current_section(5))
        focus_submenu.addAction(reduce_action)
        
        break_action = QAction("Take 5min Break", self)
        break_action.triggered.connect(self.take_quick_break)
        focus_submenu.addAction(break_action)
        
        self.tray_menu.addSeparator()
        
        # Session management
        session_submenu = self.tray_menu.addMenu("Session")
        
        analytics_action = QAction("View Analytics", self)
        analytics_action.triggered.connect(self.show_session_analytics)
        session_submenu.addAction(analytics_action)
        
        export_action = QAction("Export Progress", self)
        export_action.triggered.connect(self.export_session_progress)
        session_submenu.addAction(export_action)
        
        self.tray_menu.addSeparator()
        
        # End session action
        end_action = QAction("End Session", self)
        end_action.triggered.connect(self.stop_focus_mode)
        self.tray_menu.addAction(end_action)
        
        self.tray_icon.setContextMenu(self.tray_menu)
    
    def get_mode_display_name(self, mode):
        """Get display name for focus mode"""
        mode_names = {
            "productivity": "🏢 Productivity",
            "creativity": "🎨 Creativity", 
            "social_media_detox": "🧘 Social Media Detox"
        }
        return mode_names.get(mode, mode.title())
    
    def jump_to_section(self, section_index):
        """Jump to a specific section"""
        if hasattr(self, 'session_manager') and self.session_manager:
            self.session_manager.jump_to_section(section_index)
            self.update_tray_icon()
            self.setup_enhanced_tray_menu()  # Refresh menu
            
            # Show notification
            if hasattr(self, 'tray_icon'):
                section = self.session_manager.session_structure[section_index]
                mode_name = self.get_mode_display_name(section['mode'])
                self.tray_icon.showMessage(
                    "Section Changed",
                    f"Jumped to {mode_name} (Section {section_index + 1})",
                    QSystemTrayIcon.Information,
                    3000
                )
    
    def complete_current_section(self):
        """Mark current section as complete"""
        if hasattr(self, 'session_manager') and self.session_manager:
            self.session_manager.complete_current_section()
            self.update_tray_icon()
            self.setup_enhanced_tray_menu()  # Refresh menu
            
            # Show notification
            if hasattr(self, 'tray_icon'):
                self.tray_icon.showMessage(
                    "Section Complete!",
                    "Great work! Moving to next section...",
                    QSystemTrayIcon.Information,
                    3000
                )
    
    def extend_current_section(self, minutes):
        """Extend current section by specified minutes"""
        if hasattr(self, 'session_manager') and self.session_manager:
            self.session_manager.extend_current_section(minutes)
            
            # Show notification
            if hasattr(self, 'tray_icon'):
                self.tray_icon.showMessage(
                    "Section Extended",
                    f"Added {minutes} minutes to current section",
                    QSystemTrayIcon.Information,
                    2000
                )
    
    def reduce_current_section(self, minutes):
        """Reduce current section by specified minutes"""
        if hasattr(self, 'session_manager') and self.session_manager:
            self.session_manager.reduce_current_section(minutes)
            
            # Show notification
            if hasattr(self, 'tray_icon'):
                self.tray_icon.showMessage(
                    "Section Reduced",
                    f"Removed {minutes} minutes from current section",
                    QSystemTrayIcon.Information,
                    2000
                )
    
    def take_quick_break(self):
        """Start a full-screen break with countdown"""
        # Hide current progress popup if visible
        if hasattr(self, 'progress_popup') and self.progress_popup and self.progress_popup.isVisible():
            self.progress_popup.hide()
        
        # Create and show break screen
        self.break_screen = BreakScreen(duration_minutes=5)
        self.break_screen.break_finished.connect(self.resume_from_break)
        self.break_screen.start_break()
    
    def resume_from_break(self):
        """Resume session after break"""
        # Clean up break screen
        if hasattr(self, 'break_screen'):
            self.break_screen = None
        
        # Show progress popup again if it exists
        if hasattr(self, 'progress_popup') and self.progress_popup:
            self.progress_popup.show()
            self.progress_popup.raise_()
            self.progress_popup.activateWindow()
        
        # Show notification
        if hasattr(self, 'tray_icon'):
            self.tray_icon.showMessage(
                "Break Over!",
                "Back to focused work. You've got this! 💪",
                QSystemTrayIcon.Information,
                3000
            )
    
    def show_session_analytics(self):
        """Show quick session analytics popup"""
        if hasattr(self, 'session_manager') and self.session_manager:
            # Create quick analytics popup
            from PyQt5.QtWidgets import QMessageBox
            
            progress = self.session_manager.get_overall_progress()
            current_section = self.session_manager.current_section_index + 1
            total_sections = len(self.session_manager.session_structure)
            elapsed_time = self.session_manager.get_total_elapsed_time()
            
            analytics_text = f"""
📊 Session Analytics

🎯 Progress: {progress:.1%} complete
📍 Section: {current_section} of {total_sections}
⏱ Time Elapsed: {elapsed_time:.0f} minutes
🏆 Sections Completed: {current_section - 1}

Keep up the great work! 💪
"""
            
            msg = QMessageBox()
            msg.setWindowTitle("Session Analytics")
            msg.setText(analytics_text)
            msg.setIcon(QMessageBox.Information)
            msg.exec_()
    
    def export_session_progress(self):
        """Export current session progress"""
        # Placeholder for export functionality
        if hasattr(self, 'tray_icon'):
            self.tray_icon.showMessage(
                "Export Progress",
                "Progress export feature coming soon! 📊",
                QSystemTrayIcon.Information,
                3000
            )
    
    def setup_ai_assistant(self):
        """Initialize AI assistant components"""
        try:
            from gemini_service import GeminiService
            from agent import chat, clear_chat_history
            from plugin_system import PluginBase
            
            # Create a plugin instance that has access to this ProgressPopup
            class SessionPlugin(PluginBase):
                def __init__(self, progress_popup):
                    super().__init__()
                    self.name = "Session AI Plugin"
                    self._progress_popup = progress_popup
                
                def initialize(self) -> bool:
                    return True
                
                def cleanup(self):
                    pass
                
                def add_checklist_item(self, item_text: str) -> bool:
                    """Add a new item to the checklist. Direct implementation."""
                    print(f"DEBUG: SessionPlugin.add_checklist_item called with: '{item_text}'")
                    if self._progress_popup and hasattr(self._progress_popup, 'add_checklist_item'):
                        result = self._progress_popup.add_checklist_item(item_text)
                        print(f"DEBUG: SessionPlugin.add_checklist_item result: {result}")
                        return result
                    else:
                        print(f"DEBUG: SessionPlugin.add_checklist_item failed - no _progress_popup or method")
                        print(f"DEBUG: _progress_popup is: {self._progress_popup}")
                        if self._progress_popup:
                            print(f"DEBUG: has add_checklist_item method: {hasattr(self._progress_popup, 'add_checklist_item')}")
                        return False
            
            self.ai_service = GeminiService()
            self.ai_plugin = SessionPlugin(self)
            
            # Clear chat history at session start
            clear_chat_history()
            
        except Exception as e:
            print(f"Error setting up AI assistant: {e}")
            self.ai_service = None
            self.ai_plugin = None
    
    def show_ai_assistant(self):
        """Show the AI assistant chat window"""
        if not self.ai_service or not self.ai_service.is_available():
            self.show_ai_error("AI service not available. Please check your gemini_api_key.txt file.")
            return
        
        if self.ai_assistant_window is None:
            from ai_chat_window import AIAssistantWindow
            self.ai_assistant_window = AIAssistantWindow(self.ai_service, self.ai_plugin)
        
        self.ai_assistant_window.show()
        self.ai_assistant_window.raise_()
        self.ai_assistant_window.activateWindow()
    
    def show_ai_error(self, message):
        """Show AI error message"""
        from PyQt5.QtWidgets import QMessageBox
        msg = QMessageBox()
        msg.setWindowTitle("AI Assistant Error")
        msg.setText(message)
        msg.setIcon(QMessageBox.Warning)
        msg.exec_()
    
    def tray_icon_clicked(self, reason):
        """Handle system tray icon clicks"""
        # Removed automatic toggle on left click - context menu is already available on right-click
        pass
    
    def toggle_visibility(self):
        """Toggle progress dialog visibility"""
        if self.is_visible:
            self.hide()
            self.show_hide_action.setText("Show Progress")
            self.is_visible = False
        else:
            self.show()
            self.raise_()
            self.activateWindow()
            self.show_hide_action.setText("Hide Progress")
            self.is_visible = True
    
    def closeEvent(self, event):
        """Override close event to hide to tray instead of closing"""
        if hasattr(self, 'tray_icon') and self.tray_icon.isVisible():
            # Hide to tray instead of closing
            event.ignore()
            self.hide()
            self.show_hide_action.setText("Show Progress")
            self.is_visible = False
            
            # Hide notification removed per user request
        else:
            # No tray icon, allow normal close
            event.accept()
    
    def get_encouraging_message(self, progress):
        """Generate encouraging messages based on progress - one per popup session"""
        if not hasattr(self, '_current_message') or not hasattr(self, '_message_progress_range'):
            # First time or need new message
            if progress < 10:
                messages = [
                    "Every journey begins with a single step",
                    "You've got this! Fresh start energy",
                    "Time to dive in and make things happen",
                    "Ready to tackle some goals?"
                ]
                self._message_progress_range = (0, 10)
            elif progress < 25:
                messages = [
                    "Nice start! Building momentum now",
                    "You're finding your rhythm",
                    "Progress is progress, keep going",
                    "Good things are already happening"
                ]
                self._message_progress_range = (10, 25)
            elif progress < 50:
                messages = [
                    "You're hitting your stride now",
                    "Solid progress! Keep the energy up",
                    "Halfway there feels pretty good",
                    "You're doing great, stay focused"
                ]
                self._message_progress_range = (25, 50)
            elif progress < 75:
                messages = [
                    "Strong work! You're in the zone",
                    "The finish line is getting closer",
                    "You're crushing it today",
                    "Great momentum, keep it flowing"
                ]
                self._message_progress_range = (50, 75)
            else:
                messages = [
                    "Almost there! Final push time",
                    "You're so close to the finish",
                    "Strong finish ahead!",
                    "Time to bring it home"
                ]
                self._message_progress_range = (75, 100)
            
            import random
            self._current_message = random.choice(messages)
        
        # Check if we've moved to a new progress range
        elif not (self._message_progress_range[0] <= progress < self._message_progress_range[1]):
            # Progress moved to new range, clear message so it gets refreshed next time
            delattr(self, '_current_message')
            delattr(self, '_message_progress_range')
            return self.get_encouraging_message(progress)
        
        return self._current_message
    
    def update_progress(self):
        # Check for stop signal file
        script_dir = os.path.dirname(os.path.abspath(__file__))
        stop_signal_file = os.path.join(script_dir, 'stop_signal')
        if os.path.exists(stop_signal_file):
            # Remove the signal file and stop the session
            try:
                os.remove(stop_signal_file)
                print("DEBUG: Stop signal received - ending session")
                self.stop_focus_mode()
                return
            except Exception as e:
                print(f"Error handling stop signal: {e}")
        
        elapsed = (datetime.now() - self.start_time).total_seconds() / 60  # minutes
        progress = min(100, (elapsed / self.session_duration) * 100)
        
        # Update progress bar (segmented or regular)
        if self.is_multi_section and self.segmented_progress:
            # Update segmented progress bar
            self.segmented_progress.set_progress(progress)
        elif self.progress_bar:
            # Animate regular progress bar changes smoothly
            if hasattr(self, 'progress_animation'):
                current_value = self.progress_bar.value()
                target_value = int(progress)
                if target_value != current_value:
                    self.progress_animation.setStartValue(current_value)
                    self.progress_animation.setEndValue(target_value)
                    self.progress_animation.start()
            else:
                self.progress_bar.setValue(int(progress))
            
        # Update encouraging message
        self.encouraging_label.setText(self.get_encouraging_message(int(progress)))
        
        remaining = max(0, self.session_duration - elapsed)
        hours = int(remaining // 60)
        minutes = int(remaining % 60)
        
        if hours > 0:
            time_text = f"{hours}h {minutes}m remaining"
        else:
            time_text = f"{minutes}m remaining"
        
        self.time_label.setText(time_text)
        
        # Call session update hooks
        try:
            from plugin_system import plugin_manager
            plugin_manager.call_session_update_hooks(elapsed, progress)
        except Exception as e:
            print(f"Plugin session update hook error: {e}")
        
        # Check if session is complete
        if elapsed >= self.session_duration:
            self.session_complete()
    
    def track_app_usage(self):
        try:
            # Get current active app - use display name instead of process name
            result = subprocess.run([
                'osascript', '-e', 
                '''tell application "System Events"
                    set frontApp to first application process whose frontmost is true
                    try
                        set appName to (get name of frontApp)
                        set bundleID to (get bundle identifier of frontApp)
                        -- Map common bundle IDs to friendly names
                        if bundleID is "com.microsoft.VSCode" then
                            return "Visual Studio Code"
                        else if bundleID is "com.apple.finder" then
                            return "Finder" 
                        else if bundleID is "com.google.Chrome" then
                            return "Google Chrome"
                        else if bundleID is "com.apple.Safari" then
                            return "Safari"
                        else
                            return appName
                        end if
                    on error
                        return name of frontApp
                    end try
                end tell'''
            ], capture_output=True, text=True)
            
            current_app = result.stdout.strip()
            
            # Always track time for current app (every 5 seconds)
            if current_app:
                if current_app in self.app_usage:
                    self.app_usage[current_app] += 5  # 5 seconds
                else:
                    self.app_usage[current_app] = 5
                
                self.current_app = current_app
        except:
            pass
    
    def track_website_usage(self):
        """Track website usage by parsing browser_tabs.log"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            log_file = os.path.join(script_dir, 'browser_tabs.log')
            
            if not os.path.exists(log_file):
                return
            
            current_time = datetime.now()
            # Only check entries since last check
            with open(log_file, 'r') as f:
                for line in f:
                    if line.strip():
                        # Parse timestamp from log entry
                        try:
                            timestamp_str = line.split(']')[0][1:]  # Extract timestamp without brackets
                            entry_time = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
                            
                            # Only process entries since last check
                            if entry_time <= self.last_browser_check:
                                continue
                                
                            # Extract browser and tabs
                            if 'Chrome Tabs:' in line or 'Safari Tabs:' in line:
                                tabs_part = line.split('Tabs: ', 1)[1].strip()
                                if tabs_part and tabs_part != 'Start Page':
                                    # Split tabs by comma and extract domains
                                    tabs = [tab.strip() for tab in tabs_part.split(',')]
                                    for tab in tabs:
                                        if tab and tab != 'Start Page':
                                            # Extract domain from tab title (simplified)
                                            domain = self.extract_domain_from_tab(tab)
                                            if domain:
                                                # Add 5 seconds for this website
                                                if domain in self.website_usage:
                                                    self.website_usage[domain] += 5
                                                else:
                                                    self.website_usage[domain] = 5
                        except:
                            continue
                            
            self.last_browser_check = current_time
        except:
            pass
    
    def extract_domain_from_tab(self, tab_title):
        """Extract domain from browser tab title"""
        # Simple domain extraction based on common patterns
        domain_mappings = {
            'github': 'GitHub',
            'claude': 'Claude AI',
            'anthropic': 'Anthropic',
            'google': 'Google',
            'stackoverflow': 'Stack Overflow',
            'youtube': 'YouTube',
            'gmail': 'Gmail',
            'outlook': 'Outlook',
            'slack': 'Slack',
            'twitter': 'Twitter',
            'facebook': 'Facebook',
            'linkedin': 'LinkedIn',
            'reddit': 'Reddit',
            'docs.google': 'Google Docs',
            'drive.google': 'Google Drive'
        }
        
        tab_lower = tab_title.lower()
        for keyword, domain in domain_mappings.items():
            if keyword in tab_lower:
                return domain
        
        # If no mapping found, use first part of tab title
        if len(tab_title) > 30:
            return tab_title[:30] + '...'
        return tab_title
    
    def clear_browser_tabs_log(self):
        """Clear the browser tabs log file to start fresh for this session"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            log_file = os.path.join(script_dir, 'browser_tabs.log')
            
            # Clear the log file by opening it in write mode
            with open(log_file, 'w') as f:
                f.write('')  # Write empty content
            
            print("DEBUG: Browser tabs log cleared for new session")
        except Exception as e:
            print(f"DEBUG: Error clearing browser tabs log: {e}")
    
    def show_popup(self):
        # Reset encouraging message for each popup to ensure it only shows one per popup
        if hasattr(self, '_current_message'):
            delattr(self, '_current_message')
        if hasattr(self, '_message_progress_range'):
            delattr(self, '_message_progress_range')
        
        elapsed = (datetime.now() - self.start_time).total_seconds() / 60
        print(f"DEBUG: Showing progress popup at {elapsed:.1f} minutes")
        print(f"DEBUG: Popup timer active: {self.popup_timer.isActive()}")
        print(f"DEBUG: Progress timer active: {self.progress_timer.isActive()}")
        print(f"DEBUG: App timer active: {self.app_timer.isActive()}")
            
        self.show()
        self.raise_()
        self.activateWindow()
        # Make sure we can always click on desktop afterward
        self.setAttribute(Qt.WA_ShowWithoutActivating, False)
    
    def continue_session(self):
        """Hide the popup and continue the session"""
        self.hide()
        # Update tray menu button state
        if hasattr(self, 'show_hide_action'):
            self.show_hide_action.setText("Show Progress")
        self.is_visible = False
        
        # Send AI assistant notification on first continue (when user gets to desktop)
        if not self.ai_notification_sent and self.parent_launcher:
            self.ai_notification_sent = True
            # Delay notification slightly to ensure desktop is focused
            QTimer.singleShot(1000, self.parent_launcher.send_ai_reminder_notification)
        
        # Give focus back to the desktop/finder
        try:
            subprocess.run([
                'osascript', '-e', 
                'tell application "Finder" to activate'
            ], capture_output=True, timeout=2)
        except:
            # Fallback: just ensure this window loses focus
            self.clearFocus()
            self.setWindowState(Qt.WindowMinimized)
        
        # Make sure the popup timer keeps running so it shows again at the next interval
        if hasattr(self, 'popup_timer') and not self.popup_timer.isActive():
            print("DEBUG: Restarting popup timer after continue session")
            self.popup_timer.start(self.popup_interval * 60 * 1000)
    
    def complete_section_early(self):
        """Complete current section early and move to next section"""
        if not self.is_multi_section:
            print("Early completion only available for multi-section sessions")
            return
            
        from PyQt5.QtWidgets import QMessageBox
        
        # Get current section info
        current_section = self.session_structure[self.current_section_index]
        current_mode = current_section['mode'].replace('_', ' ').title()
        
        # Get next section info
        next_section_index = self.current_section_index + 1
        if next_section_index >= len(self.session_structure):
            print("No next section available")
            return
            
        next_section = self.session_structure[next_section_index]
        next_mode = next_section['mode'].replace('_', ' ').title()
        
        # Confirm with user
        reply = QMessageBox.question(
            self, 
            "Complete Section Early?", 
            f"Are you ready to finish the {current_mode} section early and move to {next_mode}?\n\n"
            f"This will end the current section and begin the next one immediately.",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            print(f"User requested early completion of section {self.current_section_index + 1}")
            
            # Call the session complete method to trigger section transition
            self.session_complete()
        else:
            print("User cancelled early section completion")
    
    def goal_checked(self, state):
        checkbox = self.sender()
        goal_text = checkbox.text()
        
        if state == 2:  # Checked
            self.completed_goals.add(goal_text)
        else:
            self.completed_goals.discard(goal_text)
        
        # Call plugin hooks for checklist item changes
        try:
            from plugin_system import plugin_manager
            print(f"DEBUG: Calling checklist item changed hooks for: {goal_text}, checked: {state == 2}")
            plugin_manager.call_checklist_item_changed_hooks(goal_text, state == 2)
        except Exception as e:
            print(f"Error calling checklist item changed hooks: {e}")
            import traceback
            traceback.print_exc()
    
    def session_complete(self):
        self.progress_timer.stop()
        self.popup_timer.stop()
        self.app_timer.stop()
        
        # Delete current_mode file to indicate session is ended
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            current_mode_file = os.path.join(script_dir, 'current_mode')
            if os.path.exists(current_mode_file):
                os.remove(current_mode_file)
                print("DEBUG: current_mode file deleted (session complete)")
            
            # Also clean up any leftover stop_signal file
            stop_signal_file = os.path.join(script_dir, 'stop_signal')
            if os.path.exists(stop_signal_file):
                os.remove(stop_signal_file)
                print("DEBUG: stop_signal file cleaned up")
        except Exception as e:
            print(f"Error deleting session files: {e}")
        
        # Calculate actual session duration
        actual_duration = (datetime.now() - self.start_time).total_seconds() / 60  # minutes
        
        # Call session end hooks
        try:
            from plugin_system import plugin_manager
            session_data = {
                'mode': self.mode,
                'duration': actual_duration,
                'planned_duration': self.session_duration,
                'goals': self.goals,
                'completed_goals': self.completed_goals,
                'app_usage': self.app_usage,
                'end_time': datetime.now()
            }
            plugin_manager.call_session_end_hooks(session_data)
        except Exception as e:
            print(f"Plugin session end hook error: {e}")
        
        # Show enhanced final summary
        # Prepare session data for enhanced summary
        session_structure = getattr(self, 'session_manager', None)
        if session_structure and hasattr(session_structure, 'session_structure'):
            # Multi-section session - use enhanced summary with proper data
            section_stats = []
            for i, section in enumerate(session_structure.session_structure):
                section_stats.append({
                    'actual_duration': section.get('duration_minutes', 0),
                    'planned_duration': section.get('duration_minutes', 0),
                    'todos_completed': len([g for g in self.completed_goals if g in section.get('todos', [])]),
                    'todos_planned': len(section.get('todos', []))
                })
            
            self.summary = EnhancedFinalSummaryDialog(
                session_structure=session_structure.session_structure,
                section_stats=section_stats,
                final_goals=self.goals
            )
        else:
            # Single-section session - create structure for enhanced summary
            single_section = {
                'mode': self.mode,
                'duration_minutes': int(actual_duration),
                'todos': self.goals,
                'description': f"{self.mode.replace('_', ' ').title()} Session"
            }
            section_stats = [{
                'actual_duration': actual_duration,
                'planned_duration': self.session_duration,
                'todos_completed': len(self.completed_goals),
                'todos_planned': len(self.goals)
            }]
            
            self.summary = EnhancedFinalSummaryDialog(
                session_structure=[single_section],
                section_stats=section_stats,
                final_goals=self.goals
            )
        
        self.summary.show()
        self.summary.raise_()
        self.summary.activateWindow()
        self.close()
    
    def stop_focus_mode(self):
        """Completely stop the focus mode session"""
        # Stop all timers
        if hasattr(self, 'progress_timer'):
            self.progress_timer.stop()
        if hasattr(self, 'popup_timer'):
            self.popup_timer.stop()
        if hasattr(self, 'app_timer'):
            self.app_timer.stop()
        
        # Note: Tray icon cleanup moved to SessionSummary.close_with_cleanup()
        # to avoid interfering with summary display
        
        # Delete current_mode file to indicate session is ended
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            current_mode_file = os.path.join(script_dir, 'current_mode')
            if os.path.exists(current_mode_file):
                os.remove(current_mode_file)
                print("DEBUG: current_mode file deleted (early termination)")
            
            # Also clean up any leftover stop_signal file
            stop_signal_file = os.path.join(script_dir, 'stop_signal')
            if os.path.exists(stop_signal_file):
                os.remove(stop_signal_file)
                print("DEBUG: stop_signal file cleaned up")
        except Exception as e:
            print(f"Error deleting session files: {e}")
        
        # Calculate actual session duration
        actual_duration = (datetime.now() - self.start_time).total_seconds() / 60  # minutes
        
        # Call session end hooks for early termination
        try:
            from plugin_system import plugin_manager
            session_data = {
                'mode': self.mode,
                'duration': actual_duration,
                'planned_duration': self.session_duration,
                'goals': self.goals,
                'completed_goals': self.completed_goals,
                'app_usage': self.app_usage,
                'end_time': datetime.now(),
                'early_termination': True
            }
            plugin_manager.call_session_end_hooks(session_data)
        except Exception as e:
            print(f"Plugin session end hook error: {e}")
        
        # Show session summary for premature termination
        # Show enhanced final summary for early termination
        # Prepare session data for enhanced summary
        session_structure = getattr(self, 'session_manager', None)
        if session_structure and hasattr(session_structure, 'session_structure'):
            # Multi-section session - use enhanced summary with proper data
            section_stats = []
            for i, section in enumerate(session_structure.session_structure):
                section_stats.append({
                    'actual_duration': section.get('duration_minutes', 0),
                    'planned_duration': section.get('duration_minutes', 0),
                    'todos_completed': len([g for g in self.completed_goals if g in section.get('todos', [])]),
                    'todos_planned': len(section.get('todos', []))
                })
            
            self.summary = EnhancedFinalSummaryDialog(
                session_structure=session_structure.session_structure,
                section_stats=section_stats,
                final_goals=self.goals
            )
        else:
            # Single-section session - create structure for enhanced summary
            single_section = {
                'mode': self.mode,
                'duration_minutes': int(actual_duration),
                'todos': self.goals,
                'description': f"{self.mode.replace('_', ' ').title()} Session"
            }
            section_stats = [{
                'actual_duration': actual_duration,
                'planned_duration': self.session_duration,
                'todos_completed': len(self.completed_goals),
                'todos_planned': len(self.goals)
            }]
            
            self.summary = EnhancedFinalSummaryDialog(
                session_structure=[single_section],
                section_stats=section_stats,
                final_goals=self.goals
            )
        
        self.summary.show()
        self.summary.raise_()
        self.summary.activateWindow()
        
        # Close the popup
        self.close()
    
    def end_session(self):
        """API method for plugins to end the current session"""
        self.stop_focus_mode()


class SessionSummary(QWidget):
    def __init__(self, session_duration, goals, completed_goals, app_usage, website_usage=None, session_data=None, progress_popup=None):
        super().__init__()
        self.session_duration = session_duration
        self.goals = goals
        self.completed_goals = completed_goals
        self.app_usage = app_usage
        self.website_usage = website_usage or {}
        self.session_data = session_data or {}
        self.progress_popup = progress_popup  # Keep reference to cleanup tray icon
        self.init_ui()
    
    def get_encouraging_title(self):
        """Generate encouraging but realistic title based on completion"""
        if self.goals:
            completed_count = len(self.completed_goals)
            total_count = len(self.goals)
            completion_rate = (completed_count / total_count * 100) if total_count > 0 else 0
            
            if completion_rate >= 80:
                return "Outstanding Focus Session!"
            elif completion_rate >= 60:
                return "Great Work Today!"
            elif completion_rate >= 40:
                return "Solid Progress Made!"
            elif completion_rate >= 20:
                return "Good Start - Keep Building!"
            else:
                return "Every Step Counts!"
        else:
            return "Focus Time Complete!"
    
    def init_ui(self):
        self.setWindowTitle('Session Complete')
        self.setWindowIcon(get_app_icon())
        # Use same window setup as CountdownWindow
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        self.showMaximized()
        
        # Close any other plugin dialogs that might be open
        try:
            from plugin_system import plugin_manager
            for plugin in plugin_manager.loaded_plugins.values():
                if hasattr(plugin, '_active_dialogs'):
                    for dialog in plugin._active_dialogs[:]:
                        try:
                            dialog.close()
                        except:
                            pass
                    plugin._active_dialogs.clear()
        except Exception as e:
            print(f"Error closing plugin dialogs: {e}")
        
        # Modern background with subtle gradient
        self.setStyleSheet("""
            QWidget {
                background: qlineargradient(
                    x1: 0, y1: 0, x2: 1, y2: 1,
                    stop: 0 #f5f5f7,
                    stop: 0.5 #f0f0f2,
                    stop: 1 #f5f5f7
                );
                color: #1d1d1f;
            }
        """)
        
        # Remove distracting animations for cleaner look
        
        # Clean main layout with compact spacing for more content area
        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(40, 30, 40, 40)
        main_layout.setSpacing(20)
        
        # Modern header with subtle glow
        title_text = self.get_encouraging_title()
        title = QLabel(title_text)
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            color: #1d1d1f;
            font-size: 48px;
            font-weight: 600;
            letter-spacing: -0.8px;
            margin-bottom: 4px;
            background: transparent;
            border: none;
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
        """)
        
        # Add subtle text shadow
        title_shadow = QGraphicsDropShadowEffect()
        title_shadow.setBlurRadius(10)
        title_shadow.setColor(QColor(0, 0, 0, 15))
        title_shadow.setOffset(0, 2)
        title.setGraphicsEffect(title_shadow)
        
        main_layout.addWidget(title)
        
        # Clean subtitle
        subtitle = QLabel("Session Summary")
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setStyleSheet("""
            color: #86868b;
            font-size: 17px;
            font-weight: 400;
            margin-bottom: 40px;
            background: transparent;
            border: none;
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
        """)
        main_layout.addWidget(subtitle)
        
        # Glass morphism scrollable content area
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setStyleSheet("""
            QScrollArea {
                background-color: transparent;
                border: none;
            }
            QScrollBar:vertical {
                border: none;
                background: rgba(255, 255, 255, 0.2);
                width: 8px;
                border-radius: 4px;
                margin: 4px;
            }
            QScrollBar::handle:vertical {
                background: rgba(0, 0, 0, 0.2);
                border-radius: 4px;
                min-height: 30px;
                margin: 1px;
            }
            QScrollBar::handle:vertical:hover {
                background: rgba(0, 0, 0, 0.3);
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0px;
            }
            QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
                background: none;
            }
        """)
        
        # Stats content with clean spacing
        stats_widget = QWidget()
        stats_widget.setStyleSheet("background-color: transparent;")
        stats_layout = QVBoxLayout(stats_widget)
        stats_layout.setSpacing(24)
        stats_layout.setContentsMargins(20, 0, 20, 20)
        
        # Glass morphism duration card
        duration_container = QFrame()
        duration_container.setStyleSheet("""
            QFrame {
                background: rgba(255, 255, 255, 0.7);
                border: 1px solid rgba(255, 255, 255, 0.3);
                border-radius: 24px;
                padding: 32px 24px;
                backdrop-filter: blur(20px);
            }
        """)
        
        # Add drop shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(30)
        shadow.setColor(QColor(0, 0, 0, 20))
        shadow.setOffset(0, 8)
        duration_container.setGraphicsEffect(shadow)
        
        duration_layout = QVBoxLayout(duration_container)
        duration_layout.setSpacing(10)
        
        duration_title = QLabel("Duration")
        duration_title.setAlignment(Qt.AlignCenter)
        duration_title.setStyleSheet("""
            color: #86868b;
            font-size: 13px;
            font-weight: 500;
            letter-spacing: 0.2px;
            text-transform: uppercase;
            background: transparent;
            border: none;
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            margin-bottom: 4px;
        """)
        duration_layout.addWidget(duration_title)
        
        # Format duration nicely
        total_minutes = int(self.session_duration)
        seconds = int((self.session_duration - total_minutes) * 60)
        
        if total_minutes > 0 and seconds > 0:
            duration_text = f"{total_minutes} minutes {seconds} seconds"
        elif total_minutes > 0:
            duration_text = f"{total_minutes} minutes"
        else:
            duration_text = f"{seconds} seconds"
            
        duration_value = QLabel(duration_text)
        duration_value.setAlignment(Qt.AlignCenter)
        duration_value.setStyleSheet("""
            color: #1d1d1f;
            font-size: 32px;
            font-weight: 600;
            letter-spacing: -0.4px;
            background: transparent;
            border: none;
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
        """)
        duration_layout.addWidget(duration_value)
        
        stats_layout.addWidget(duration_container)
        
        # Goals completion if we have goals
        if self.goals:
            completed_count = len(self.completed_goals)
            total_count = len(self.goals)
            completion_rate = (completed_count / total_count * 100) if total_count > 0 else 0
            
            goals_container = QFrame()
            goals_container.setStyleSheet("""
                QFrame {
                    background: rgba(255, 255, 255, 0.7);
                    border: 1px solid rgba(255, 255, 255, 0.3);
                    border-radius: 24px;
                    padding: 32px 24px;
                    backdrop-filter: blur(20px);
                }
            """)
            
            # Add drop shadow effect
            goals_shadow = QGraphicsDropShadowEffect()
            goals_shadow.setBlurRadius(30)
            goals_shadow.setColor(QColor(0, 0, 0, 20))
            goals_shadow.setOffset(0, 8)
            goals_container.setGraphicsEffect(goals_shadow)
            goals_layout = QVBoxLayout(goals_container)
            goals_layout.setSpacing(15)
            
            goals_title = QLabel("Goals")
            goals_title.setAlignment(Qt.AlignCenter)
            goals_title.setStyleSheet("""
                color: #86868b;
                font-size: 13px;
                font-weight: 500;
                letter-spacing: 0.2px;
                text-transform: uppercase;
                background: transparent;
                border: none;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                margin-bottom: 4px;
            """)
            goals_layout.addWidget(goals_title)
            
            goals_value = QLabel(f"{completed_count}/{total_count}")
            goals_value.setAlignment(Qt.AlignCenter)
            goals_value.setStyleSheet("""
                color: #1d1d1f;
                font-size: 32px;
                font-weight: 600;
                letter-spacing: -0.4px;
                background: transparent;
                border: none;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
                margin-bottom: 16px;
            """)
            goals_layout.addWidget(goals_value)
            
            # Individual goals list
            for goal in self.goals:
                is_completed = goal in self.completed_goals
                # Create a horizontal layout for each goal
                goal_container = QWidget()
                goal_layout = QHBoxLayout(goal_container)
                goal_layout.setContentsMargins(0, 4, 0, 4)
                
                # Status indicator with glow effect
                status_icon = QLabel("●")
                status_icon.setStyleSheet(f"""
                    color: {'#34c759' if is_completed else 'rgba(199, 199, 204, 0.6)'};
                    font-size: 14px;
                    margin-right: 8px;
                """)
                
                if is_completed:
                    # Add subtle glow to completed items
                    status_glow = QGraphicsDropShadowEffect()
                    status_glow.setBlurRadius(8)
                    status_glow.setColor(QColor(52, 199, 89, 100))
                    status_glow.setOffset(0, 0)
                    status_icon.setGraphicsEffect(status_glow)
                
                # Goal text
                goal_text = QLabel(goal.replace('• ', ''))
                goal_text.setWordWrap(True)
                goal_text.setStyleSheet(f"""
                    color: {'#1d1d1f' if is_completed else '#86868b'};
                    font-size: 15px;
                    font-weight: 400;
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                    {'text-decoration: line-through;' if is_completed else ''}
                """)
                
                goal_layout.addWidget(status_icon)
                goal_layout.addWidget(goal_text)
                goal_layout.addStretch()
                goals_layout.addWidget(goal_container)
            
            stats_layout.addWidget(goals_container)
        
        # Top apps if we have usage data
        if self.app_usage:
            apps_container = QFrame()
            apps_container.setStyleSheet("""
                QFrame {
                    background: rgba(255, 255, 255, 0.7);
                    border: 1px solid rgba(255, 255, 255, 0.3);
                    border-radius: 24px;
                    padding: 32px 24px;
                    backdrop-filter: blur(20px);
                }
            """)
            
            # Add drop shadow effect
            apps_shadow = QGraphicsDropShadowEffect()
            apps_shadow.setBlurRadius(30)
            apps_shadow.setColor(QColor(0, 0, 0, 20))
            apps_shadow.setOffset(0, 8)
            apps_container.setGraphicsEffect(apps_shadow)
            apps_layout = QVBoxLayout(apps_container)
            apps_layout.setSpacing(10)
            
            apps_title = QLabel("Top Apps")
            apps_title.setAlignment(Qt.AlignCenter)
            apps_title.setStyleSheet("""
                color: #86868b;
                font-size: 13px;
                font-weight: 500;
                letter-spacing: 0.2px;
                text-transform: uppercase;
                margin-bottom: 16px;
                background: transparent;
                border: none;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            """)
            apps_layout.addWidget(apps_title)
            
            # Show top 5 apps (excluding focus launcher related apps)
            focus_related_apps = ['focus_launcher.py', 'Python', 'focus_launcher', 'focusmode.py', 'Terminal']
            filtered_apps = {app: time for app, time in self.app_usage.items() 
                           if not any(focus_app.lower() in app.lower() for focus_app in focus_related_apps)}
            top_apps = sorted(filtered_apps.items(), key=lambda x: x[1], reverse=True)[:5]
            for i, (app, seconds) in enumerate(top_apps):
                minutes = seconds // 60
                remaining_seconds = seconds % 60
                time_str = f"{minutes}m {remaining_seconds}s" if minutes > 0 else f"{remaining_seconds}s"
                
                app_item = QLabel(f"{app} — {time_str}")
                app_item.setStyleSheet("""
                    color: #1d1d1f;
                    font-size: 15px;
                    font-weight: 400;
                    padding: 4px 0px;
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                """)
                apps_layout.addWidget(app_item)
            
            stats_layout.addWidget(apps_container)
        
        # Top websites if we have usage data
        if self.website_usage:
            websites_container = QFrame()
            websites_container.setStyleSheet("""
                QFrame {
                    background: rgba(255, 255, 255, 0.7);
                    border: 1px solid rgba(255, 255, 255, 0.3);
                    border-radius: 24px;
                    padding: 32px 24px;
                    backdrop-filter: blur(20px);
                }
            """)
            
            # Add drop shadow effect
            websites_shadow = QGraphicsDropShadowEffect()
            websites_shadow.setBlurRadius(30)
            websites_shadow.setColor(QColor(0, 0, 0, 20))
            websites_shadow.setOffset(0, 8)
            websites_container.setGraphicsEffect(websites_shadow)
            websites_layout = QVBoxLayout(websites_container)
            websites_layout.setSpacing(10)
            
            websites_title = QLabel("Top Websites")
            websites_title.setAlignment(Qt.AlignCenter)
            websites_title.setStyleSheet("""
                color: #86868b;
                font-size: 13px;
                font-weight: 500;
                letter-spacing: 0.2px;
                text-transform: uppercase;
                margin-bottom: 16px;
                background: transparent;
                border: none;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            """)
            websites_layout.addWidget(websites_title)
            
            # Show top 5 websites
            top_websites = sorted(self.website_usage.items(), key=lambda x: x[1], reverse=True)[:5]
            for i, (website, seconds) in enumerate(top_websites):
                minutes = seconds // 60
                remaining_seconds = seconds % 60
                time_str = f"{minutes}m {remaining_seconds}s" if minutes > 0 else f"{remaining_seconds}s"
                
                website_item = QLabel(f"{website} — {time_str}")
                website_item.setStyleSheet("""
                    color: #1d1d1f;
                    font-size: 15px;
                    font-weight: 400;
                    padding: 4px 0px;
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                """)
                websites_layout.addWidget(website_item)
            
            stats_layout.addWidget(websites_container)
        
        scroll.setWidget(stats_widget)
        
        # Add scroll indicator hint
        scroll_hint = QLabel("↓ Scroll down to see detailed stats ↓")
        scroll_hint.setAlignment(Qt.AlignCenter)
        scroll_hint.setStyleSheet("""
            color: #007aff;
            font-size: 14px;
            font-weight: 500;
            margin: 8px 0;
            padding: 8px;
            background: rgba(0, 122, 255, 0.1);
            border-radius: 12px;
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
        """)
        main_layout.addWidget(scroll_hint)
        
        main_layout.addWidget(scroll)
        
        # Glass morphism continue button
        close_btn = QPushButton("Continue")
        close_btn.clicked.connect(self.close_with_cleanup)
        close_btn.setStyleSheet("""
            QPushButton {
                padding: 16px 40px;
                font-size: 17px;
                font-weight: 500;
                border: 1px solid rgba(0, 122, 255, 0.3);
                border-radius: 20px;
                background: rgba(0, 122, 255, 0.8);
                color: #ffffff;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                backdrop-filter: blur(20px);
            }
            QPushButton:hover {
                background: rgba(0, 122, 255, 0.9);
                border: 1px solid rgba(0, 122, 255, 0.5);
            }
            QPushButton:pressed {
                background: rgba(0, 122, 255, 1.0);
                transform: scale(0.98);
            }
        """)
        
        # Add button shadow
        btn_shadow = QGraphicsDropShadowEffect()
        btn_shadow.setBlurRadius(20)
        btn_shadow.setColor(QColor(0, 122, 255, 60))
        btn_shadow.setOffset(0, 4)
        close_btn.setGraphicsEffect(btn_shadow)
        main_layout.addWidget(close_btn, 0, Qt.AlignCenter)
        
        # Clean ESC instruction
        esc_label = QLabel("Press ESC to close")
        esc_label.setAlignment(Qt.AlignCenter)
        esc_label.setStyleSheet("""
            color: #86868b;
            font-size: 13px;
            font-weight: 400;
            margin-top: 16px;
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
        """)
        main_layout.addWidget(esc_label)
        
        self.setLayout(main_layout)
    
    def paintEvent(self, event):
        """Clean paint event without distracting animations"""
        super().paintEvent(event)
    
    
    def close_with_cleanup(self):
        """Close with proper cleanup and exit"""
        # Call summary closed hooks before cleanup
        print("DEBUG: close_with_cleanup called")
        try:
            from plugin_system import plugin_manager
            print(f"DEBUG: Plugin manager has {len(plugin_manager.loaded_plugins)} loaded plugins")
            print(f"DEBUG: Loaded plugins: {list(plugin_manager.loaded_plugins.keys())}")
            print("DEBUG: Calling summary closed hooks")
            plugin_manager.call_summary_closed_hooks(self.session_data)
            print("DEBUG: Summary closed hooks completed")
        except Exception as e:
            print(f"Plugin summary closed hook error: {e}")
            import traceback
            traceback.print_exc()
        
        # Clean up AI assistant window before closing
        if self.progress_popup and hasattr(self.progress_popup, 'ai_assistant_window'):
            try:
                if self.progress_popup.ai_assistant_window:
                    # Force close and delete the window
                    self.progress_popup.ai_assistant_window.hide()
                    self.progress_popup.ai_assistant_window.deleteLater()
                    self.progress_popup.ai_assistant_window = None
                    print("DEBUG: AI assistant window cleaned up")
            except Exception as e:
                print(f"DEBUG: Error cleaning up AI assistant window: {e}")
        
        # Clean up progress popup completely
        if self.progress_popup:
            try:
                # Stop any timers
                if hasattr(self.progress_popup, 'timer'):
                    self.progress_popup.timer.stop()
                if hasattr(self.progress_popup, 'app_timer'):
                    self.progress_popup.app_timer.stop()
                if hasattr(self.progress_popup, 'browser_timer'):
                    self.progress_popup.browser_timer.stop()
                
                # Clean up tray icon before deleting popup
                if hasattr(self.progress_popup, 'tray_icon'):
                    self.progress_popup.tray_icon.hide()
                    self.progress_popup.tray_icon = None
                
                # Hide and delete the progress popup
                self.progress_popup.hide()
                self.progress_popup.deleteLater()
                self.progress_popup = None
                print("DEBUG: Progress popup cleaned up")
            except Exception as e:
                print(f"DEBUG: Error cleaning up progress popup: {e}")
        
        # Force close any remaining windows
        from PyQt5.QtWidgets import QApplication
        app = QApplication.instance()
        if app:
            app.closeAllWindows()
            print("DEBUG: All windows closed")
        
        self.close()
        
        # Kill background processes with password dialog if needed
        stop_focus_mode_with_password()
        
        # Exit the application after cleanup is complete
        import sys
        sys.exit(0)
    
    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.close_with_cleanup()
    
    def showEvent(self, event):
        """Override showEvent to ensure proper focus and visibility"""
        super().showEvent(event)
        self.raise_()
        self.activateWindow()
        self.setFocus()

class PasswordDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.password = None
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Authentication Required')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(400, 300)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # Add shadow effect
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 80))
        shadow.setOffset(0, 10)
        self.setGraphicsEffect(shadow)
        
        # Center the dialog
        self.center_window()
        
        # Main container with rounded corners
        self.setStyleSheet("""
            QDialog {
                background-color: white;
                border-radius: 20px;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(20)
        
        # Icon and title
        title_layout = QHBoxLayout()
        title_layout.setSpacing(15)
        
        icon_label = QLabel("LOCK")
        icon_label.setStyleSheet("font-size: 16px; font-weight: bold; color: #007aff;")
        title_layout.addWidget(icon_label)
        
        title_label = QLabel("Administrator Password Required")
        title_label.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        title_layout.addWidget(title_label)
        title_layout.addStretch()
        
        layout.addLayout(title_layout)
        
        # Subtitle
        subtitle = QLabel("Enter your password to enable website blocking")
        subtitle.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
            margin-bottom: 10px;
        """)
        layout.addWidget(subtitle)
        
        # Password input
        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.Password)
        self.password_input.setPlaceholderText("Password")
        self.password_input.setStyleSheet("""
            QLineEdit {
                padding: 12px 16px;
                font-size: 16px;
                border: 2px solid #e5e5e7;
                border-radius: 12px;
                background-color: white;
                selection-background-color: #007aff;
            }
            QLineEdit:focus {
                border-color: #007aff;
                outline: none;
            }
        """)
        layout.addWidget(self.password_input)
        
        # Buttons
        button_layout = QHBoxLayout()
        button_layout.setSpacing(12)
        
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        cancel_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 500;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: white;
                color: #1d1d1f;
            }
            QPushButton:hover {
                background-color: #f5f5f7;
            }
            QPushButton:pressed {
                background-color: #e5e5e7;
            }
        """)
        
        ok_btn = QPushButton("Authenticate")
        ok_btn.clicked.connect(self.accept_password)
        ok_btn.setDefault(True)
        ok_btn.setStyleSheet("""
            QPushButton {
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 600;
                border: none;
                border-radius: 8px;
                background-color: #007aff;
                color: white;
            }
            QPushButton:hover {
                background-color: #0056cc;
            }
            QPushButton:pressed {
                background-color: #004499;
            }
        """)
        
        button_layout.addStretch()
        button_layout.addWidget(cancel_btn)
        button_layout.addWidget(ok_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
        
        # Focus on password input
        self.password_input.setFocus()
        
        # Connect Enter key
        self.password_input.returnPressed.connect(self.accept_password)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def accept_password(self):
        self.password = self.password_input.text()
        if self.password:
            self.accept()

class BreathingCircle(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowIcon(get_app_icon())
        self.radius = 60
        self.min_radius = 60
        self.max_radius = 120
        self.breathing_in = True
        self.setFixedSize(300, 300)
        
        # Breathing animation timer
        self.animation_timer = QTimer()
        self.animation_timer.timeout.connect(self.update_breathing)
        self.animation_timer.start(50)  # 20 FPS
        
        # Breathing cycle counter
        self.breath_progress = 0
        self.breath_speed = 0.02  # Speed of breathing cycle
        
        
    def update_breathing(self):
        # Create smooth breathing pattern (4 seconds in, 4 seconds out)
        self.breath_progress += self.breath_speed
        
        # Use sine wave for smooth breathing motion
        sine_value = math.sin(self.breath_progress)
        
        # Map sine wave (-1 to 1) to radius range
        radius_range = self.max_radius - self.min_radius
        self.radius = self.min_radius + (radius_range * (sine_value + 1) / 2)
        
        self.update()
    
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Calculate center
        center_x = self.width() // 2
        center_y = self.height() // 2
        
        # Create gradient effect
        gradient_color = QColor(0, 122, 255, int(100 + 50 * math.sin(self.breath_progress)))
        
        # Draw outer glow
        glow_radius = self.radius + 20
        glow_color = QColor(0, 122, 255, 30)
        painter.setBrush(QBrush(glow_color))
        painter.setPen(Qt.NoPen)
        painter.drawEllipse(int(center_x - glow_radius), int(center_y - glow_radius), 
                          int(glow_radius * 2), int(glow_radius * 2))
        
        # Draw main circle
        painter.setBrush(QBrush(gradient_color))
        painter.setPen(QPen(QColor(0, 122, 255, 150), 2))
        painter.drawEllipse(int(center_x - self.radius), int(center_y - self.radius), 
                          int(self.radius * 2), int(self.radius * 2))

class ClickableLabel(QLabel):
    def __init__(self, text, full_text):
        super().__init__(text)
        self.short_text = text
        self.full_text = full_text
        self.expanded = False
        self.setCursor(Qt.PointingHandCursor)
    
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            if self.expanded:
                self.setText(self.short_text)
                self.expanded = False
            else:
                self.setText(self.full_text)
                self.expanded = True

class CountdownManager:
    def __init__(self, mode, app):
        self.mode = mode
        self.app = app
        self.countdown_windows = []
        self.countdown_finished = False
        self.create_countdown_windows()
    
    def create_countdown_windows(self):
        """Create countdown windows for all connected displays"""
        from PyQt5.QtWidgets import QDesktopWidget
        desktop = QDesktopWidget()
        
        # Create a countdown window for each screen
        for i in range(desktop.screenCount()):
            screen = desktop.screenGeometry(i)
            window = CountdownWindow(self.mode, screen, self)  # Pass manager reference
            self.countdown_windows.append(window)
    
    def on_window_finished(self):
        """Called when any countdown window finishes"""
        self.countdown_finished = True
        # Close all other windows
        self.close()
    
    def on_window_escaped(self):
        """Called when user presses Escape on any window"""
        self.countdown_finished = True
        # Close all windows
        self.close()
        # Exit the application
        import sys
        sys.exit(0)
    
    def show(self):
        """Show all countdown windows"""
        for window in self.countdown_windows:
            window.show()
    
    def close(self):
        """Close all countdown windows"""
        for window in self.countdown_windows:
            window.close()
        self.countdown_windows.clear()
    
    def isVisible(self):
        """Check if any countdown window is visible"""
        return any(window.isVisible() for window in self.countdown_windows)
    
    def isFullScreen(self):
        """Check if any countdown window is fullscreen"""
        return any(window.isFullScreen() for window in self.countdown_windows)
    
    def showNormal(self):
        """Show all windows in normal mode (exit fullscreen)"""
        for window in self.countdown_windows:
            if window.isFullScreen():
                window.showNormal()
    
    def check_countdown_finished(self):
        """Check if countdown is finished on any window"""
        if self.countdown_windows:
            # All windows share the same countdown, so check the first one
            self.countdown_finished = self.countdown_windows[0].countdown_finished
        return self.countdown_finished

class CountdownWindow(QWidget):
    def __init__(self, mode, screen=None, manager=None):
        super().__init__()
        self.mode = mode
        self.countdown = get_breath_duration_setting()
        self.allowed_apps = self.get_allowed_apps(mode)
        self.countdown_finished = False
        self.screen = screen  # Specific screen to show on
        self.manager = manager  # Reference to CountdownManager
        self.init_ui()
        self.start_countdown()
    
    def get_allowed_apps(self, mode):
        """Read allowed apps from the mode file"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            mode_file = os.path.join(script_dir, 'modes', f'{mode}.txt')
            with open(mode_file, 'r') as f:
                apps = [line.strip() for line in f.readlines() if line.strip()]
            return apps
        except Exception:
            return []
    
    def init_ui(self):
        self.setWindowIcon(get_app_icon())
        # Make fullscreen and remove window decorations
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # If a specific screen is provided, position on that screen
        if self.screen:
            self.setGeometry(self.screen)
        
        self.showFullScreen()
        
        # Black background
        self.setStyleSheet("background-color: #000000;")
        
        # Main layout
        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(50, 50, 50, 50)
        
        # Top section with mode title
        mode_label = QLabel(f"{self.mode.title()} Mode")
        mode_label.setAlignment(Qt.AlignCenter)
        mode_label.setStyleSheet("""
            color: #007aff;
            font-size: 36px;
            font-weight: bold;
            margin-bottom: 20px;
        """)
        main_layout.addWidget(mode_label)
        
        # Center section with breathing circle
        center_layout = QVBoxLayout()
        center_layout.setAlignment(Qt.AlignCenter)
        
        starting_label = QLabel("Take a deep breath and prepare to focus")
        starting_label.setAlignment(Qt.AlignCenter)
        starting_label.setStyleSheet("""
            color: #ffffff;
            font-size: 20px;
            margin-bottom: 30px;
        """)
        center_layout.addWidget(starting_label)
        
        # Breathing circle
        self.breathing_circle = BreathingCircle()
        center_layout.addWidget(self.breathing_circle, 0, Qt.AlignCenter)
        
        main_layout.addLayout(center_layout)
        
        # Bottom section with countdown and apps
        bottom_layout = QVBoxLayout()
        bottom_layout.setAlignment(Qt.AlignCenter)
        
        # Cancel instruction
        cancel_label = QLabel("Press ESC to cancel")
        cancel_label.setAlignment(Qt.AlignCenter)
        cancel_label.setStyleSheet("""
            color: #86868b;
            font-size: 16px;
            margin-bottom: 30px;
        """)
        bottom_layout.addWidget(cancel_label)
        
        # Allowed apps list - clickable
        if self.allowed_apps:
            short_text = "Allowed: " + " • ".join(self.allowed_apps[:4])
            if len(self.allowed_apps) > 4:
                short_text += f" • +{len(self.allowed_apps) - 4} more (click to expand)"
            full_text = "Allowed: " + " • ".join(self.allowed_apps) + " (click to collapse)"
        else:
            short_text = full_text = "No restrictions loaded"
            
        self.apps_label = ClickableLabel(short_text, full_text)
        self.apps_label.setAlignment(Qt.AlignCenter)
        self.apps_label.setWordWrap(True)
        self.apps_label.setStyleSheet("""
            color: #666666;
            font-size: 12px;
            margin: 0px 100px 20px 100px;
            line-height: 1.4;
        """)
        bottom_layout.addWidget(self.apps_label)
        
        main_layout.addLayout(bottom_layout)
        
        # Countdown in corner - more visible
        self.countdown_label = QLabel("15")
        self.countdown_label.setStyleSheet("""
            color: #ffffff;
            font-size: 32px;
            font-weight: bold;
            background-color: rgba(0, 122, 255, 150);
            padding: 15px;
            border-radius: 10px;
            border: 2px solid rgba(255, 255, 255, 100);
        """)
        self.countdown_label.setFixedSize(80, 80)
        self.countdown_label.setAlignment(Qt.AlignCenter)
        
        # Position countdown in top-right corner (will be positioned after show)
        self.countdown_label.setParent(self)
        
        self.setLayout(main_layout)
        
        # Use a timer to position the countdown after everything is loaded
        QTimer.singleShot(100, self.position_countdown)
    
    def position_countdown(self):
        """Position the countdown label in the top-right corner"""
        if hasattr(self, 'countdown_label'):
            self.countdown_label.move(self.width() - 100, 20)
    
    def showEvent(self, event):
        super().showEvent(event)
        # Position countdown label after window is shown
        self.position_countdown()
    
    def resizeEvent(self, event):
        super().resizeEvent(event)
        # Reposition countdown label when window is resized
        self.position_countdown()
    
    def start_countdown(self):
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_countdown)
        self.timer.start(1000)  # 1 second interval
    
    def update_countdown(self):
        if self.countdown > 0:
            self.countdown_label.setText(str(self.countdown))
            
            # Change color as countdown progresses
            if self.countdown <= 5:
                color = "#ff3b30"  # Red
            elif self.countdown <= 10:
                color = "#ff9500"  # Orange
            else:
                color = "#007aff"  # Blue
            
            self.countdown_label.setStyleSheet(f"""
                color: {color};
                font-size: 120px;
                font-weight: bold;
                margin: 20px;
            """)
            
            self.countdown -= 1
        else:
            self.timer.stop()
            self.breathing_circle.animation_timer.stop()
            self.countdown_finished = True
            if self.manager:
                self.manager.on_window_finished()
            else:
                self.close()
    
    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.timer.stop()
            self.breathing_circle.animation_timer.stop()
            self.countdown_finished = True
            if self.manager:
                self.manager.on_window_escaped()
            else:
                self.close()
                import sys
                sys.exit(0)

class FocusSelector(QWidget):
    def __init__(self):
        super().__init__()
        self.selected_mode = None
        self.modes = ['productivity', 'creativity', 'social_media_detox']
        self.custom_modes = self._discover_custom_modes()
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Focus Mode Selector')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(600, 550)
        
        # Ensure window comes to front when opened
        self.activateWindow()
        self.raise_()
        
        # Center the window
        self.center_window()
        
        # Simple solid background - back to what worked
        self.setStyleSheet("""
            QWidget {
                background-color: #f0f0f0;
                font-family: Helvetica, Arial;
            }
        """)
        
        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(40, 40, 40, 40)
        main_layout.setSpacing(32)
        
        # Header section
        header_layout = QVBoxLayout()
        header_layout.setSpacing(8)
        
        # Top bar with settings button
        top_bar_layout = QHBoxLayout()
        top_bar_layout.addStretch()
        
        # Settings button
        settings_btn = QPushButton("Settings")
        settings_btn.setFixedSize(80, 35)
        settings_btn.clicked.connect(self.show_plugin_settings)
        settings_btn.setStyleSheet("""
            QPushButton {
                background-color: #e0e0e0;
                border: none;
                border-radius: 17px;
                font-size: 16px;
                color: #666;
            }
            QPushButton:hover {
                background-color: #d0d0d0;
                color: #333;
            }
            QPushButton:pressed {
                background-color: #c0c0c0;
            }
        """)
        settings_btn.setToolTip("Settings")
        top_bar_layout.addWidget(settings_btn)
        
        header_layout.addLayout(top_bar_layout)
        
        # Large focus icon - removed emoji
        icon_label = QLabel("FOCUS")
        icon_label.setAlignment(Qt.AlignCenter)
        icon_label.setStyleSheet("""
            font-size: 32px;
            font-weight: bold;
            color: #007aff;
            margin-bottom: 16px;
        """)
        header_layout.addWidget(icon_label)
        
        # Title
        title = QLabel("Focus")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 28px;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 8px;
        """)
        header_layout.addWidget(title)
        
        # Subtitle
        subtitle = QLabel("Choose your focus mode and blocking preferences")
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setStyleSheet("""
            font-size: 16px;
            color: #86868b;
            font-weight: 400;
            line-height: 1.4;
        """)
        header_layout.addWidget(subtitle)
        
        main_layout.addLayout(header_layout)
        
        # Mode selection cards
        mode_layout = QVBoxLayout()
        mode_layout.setSpacing(16)
        
        mode_label = QLabel("Focus Mode")
        mode_label.setStyleSheet("""
            font-size: 16px;
            font-weight: 500;
            color: #1d1d1f;
            margin-bottom: 8px;
        """)
        mode_layout.addWidget(mode_label)
        
        self.mode_combo = QComboBox()
        self.mode_combo.addItem("Select a mode...")
        self.mode_combo.addItem("Productivity - Work and focus apps only")
        self.mode_combo.addItem("Creativity - Design and creative tools")
        self.mode_combo.addItem("Social Media Detox - Digital wellness and deep focus")
        
        # Add custom modes if any exist
        if self.custom_modes:
            self.mode_combo.addItem("--- Custom Modes ---")
            for custom_mode in self.custom_modes:
                display_name = custom_mode.replace('_', ' ').title()
                self.mode_combo.addItem(f"{display_name} - Custom mode")
        
        # Add option to create new custom mode
        self.mode_combo.addItem("--- Create New ---")
        self.mode_combo.addItem("Create Custom Mode...")
        
        self.mode_combo.setStyleSheet("""
            QComboBox {
                padding: 16px 20px;
                font-size: 15px;
                font-weight: 400;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: white;
                color: #1d1d1f;
                min-height: 16px;
            }
            QComboBox:hover {
                border-color: #007aff;
            }
            QComboBox:focus {
                border-color: #007aff;
            }
            QComboBox::drop-down {
                border: none;
                width: 25px;
            }
            QComboBox::down-arrow {
                image: none;
                border-left: 5px solid transparent;
                border-right: 5px solid transparent;
                border-top: 5px solid #86868b;
                margin-right: 10px;
            }
            QComboBox QAbstractItemView {
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                background-color: white;
                selection-background-color: #007aff;
                selection-color: white;
                padding: 4px;
                font-weight: 400;
            }
        """)
        mode_layout.addWidget(self.mode_combo)
        
        main_layout.addLayout(mode_layout)
        
        # Info about full blocking being always enabled
        info_layout = QVBoxLayout()
        info_layout.setSpacing(8)
        
        info_label = QLabel("Full Protection Mode")
        info_label.setStyleSheet("""
            font-size: 16px;
            font-weight: 500;
            color: #1d1d1f;
            margin-bottom: 4px;
        """)
        info_layout.addWidget(info_label)
        
        info_desc = QLabel("Apps + Websites blocking enabled")
        info_desc.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
            margin-bottom: 8px;
        """)
        info_layout.addWidget(info_desc)
        
        main_layout.addLayout(info_layout)
        
        # Start button
        start_button = QPushButton("Begin Focus Session")
        start_button.clicked.connect(self.start_focus)
        start_button.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, 
                    stop:0 #007aff, stop:1 #0056cc);
                color: white;
                border: none;
                border-radius: 16px;
                padding: 20px 32px;
                font-size: 18px;
                font-weight: 600;
                letter-spacing: 0.5px;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, 
                    stop:0 #0056cc, stop:1 #004499);
            }
            QPushButton:pressed {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, 
                    stop:0 #004499, stop:1 #003366);
            }
        """)
        
        main_layout.addWidget(start_button)
        main_layout.addStretch()
        
        self.setLayout(main_layout)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def show_plugin_settings(self):
        """Show the plugin settings window"""
        try:
            from plugin_settings_dialog import PluginSettingsDialog
            self.settings_window = PluginSettingsDialog(self)
            self.settings_window.show()
            self.settings_window.raise_()
            self.settings_window.activateWindow()
        except Exception as e:
            print(f"Error showing plugin settings: {e}")
    
    def start_focus(self):
        index = self.mode_combo.currentIndex()
        if index <= 0:  # "Select a mode..."
            return
            
        selected_text = self.mode_combo.currentText()
        
        # Handle custom mode creation
        if selected_text == "Create Custom Mode...":
            self.create_custom_mode()
            return
        
        # Skip separator items
        if selected_text.startswith("---"):
            return
        
        # Handle built-in modes
        if index <= len(self.modes):
            self.selected_mode = self.modes[index - 1]
        else:
            # Handle custom modes
            custom_mode_index = index - len(self.modes) - 1  # Account for separator
            if selected_text.startswith("--- Custom Modes ---"):
                custom_mode_index -= 1  # Account for custom modes separator
            if selected_text.startswith("--- Create New ---"):
                custom_mode_index -= 1  # Account for create new separator
            
            # Extract custom mode name from display text
            for custom_mode in self.custom_modes:
                display_name = custom_mode.replace('_', ' ').title()
                if display_name in selected_text:
                    self.selected_mode = f"custom/{custom_mode}"
                    break
        
        if hasattr(self, 'selected_mode') and self.selected_mode:
            self.use_website_blocking = True  # Always use full blocking
            self.close()
    
    def _discover_custom_modes(self):
        """Discover available custom modes"""
        try:
            import os
            script_dir = os.path.dirname(os.path.abspath(__file__))
            custom_dir = os.path.join(script_dir, 'modes', 'custom')
            
            if not os.path.exists(custom_dir):
                return []
            
            custom_modes = []
            for filename in os.listdir(custom_dir):
                if filename.endswith('.txt'):
                    mode_name = filename.replace('.txt', '')
                    custom_modes.append(mode_name)
            
            return sorted(custom_modes)
        except Exception as e:
            print(f"Error discovering custom modes: {e}")
            return []
    
    def create_custom_mode(self):
        """Show the custom mode creation dialog"""
        try:
            from custom_mode_dialog import CustomModeDialog
            dialog = CustomModeDialog(self)
            if dialog.exec_() == QDialog.Accepted:
                # Refresh the custom modes and combo box
                self.custom_modes = self._discover_custom_modes()
                self._refresh_combo_box()
        except Exception as e:
            print(f"Error creating custom mode: {e}")
            from PyQt5.QtWidgets import QMessageBox
            QMessageBox.critical(self, "Error", f"Failed to open custom mode dialog:\n{str(e)}")
    
    def _refresh_combo_box(self):
        """Refresh the combo box to include new custom modes"""
        current_index = self.mode_combo.currentIndex()
        self.mode_combo.clear()
        
        # Re-populate combo box
        self.mode_combo.addItem("Select a mode...")
        self.mode_combo.addItem("Productivity - Work and focus apps only")
        self.mode_combo.addItem("Creativity - Design and creative tools")
        self.mode_combo.addItem("Social Media Detox - Digital wellness and deep focus")
        
        # Add custom modes if any exist
        if self.custom_modes:
            self.mode_combo.addItem("--- Custom Modes ---")
            for custom_mode in self.custom_modes:
                display_name = custom_mode.replace('_', ' ').title()
                self.mode_combo.addItem(f"{display_name} - Custom mode")
        
        # Add option to create new custom mode
        self.mode_combo.addItem("--- Create New ---")
        self.mode_combo.addItem("Create Custom Mode...")
    
    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Return or event.key() == Qt.Key_Enter:
            self.start_focus()

class BreakScreen(QWidget):
    """Full-screen break countdown window"""
    
    break_finished = pyqtSignal()  # Signal when break is complete
    
    def __init__(self, duration_minutes=5):
        super().__init__()
        self.duration_minutes = duration_minutes
        self.remaining_seconds = duration_minutes * 60
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_countdown)
        
        self.init_ui()
        self.show_fullscreen()
        
    def init_ui(self):
        """Initialize the break screen UI"""
        self.setWindowTitle("Break Time")
        self.setStyleSheet("""
            QWidget {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #667eea, stop:1 #764ba2);
                color: white;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setAlignment(Qt.AlignCenter)
        layout.setSpacing(40)
        
        # Break icon/title
        title = QLabel("☕ Break Time")
        title.setStyleSheet("""
            font-size: 72px;
            font-weight: 300;
            margin-bottom: 20px;
        """)
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # Countdown display
        self.countdown_label = QLabel()
        self.countdown_label.setStyleSheet("""
            font-size: 120px;
            font-weight: 200;
            margin: 40px 0;
        """)
        self.countdown_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.countdown_label)
        
        # Subtitle
        subtitle = QLabel("Take a moment to rest and recharge")
        subtitle.setStyleSheet("""
            font-size: 24px;
            font-weight: 300;
            opacity: 0.8;
            margin-bottom: 40px;
        """)
        subtitle.setAlignment(Qt.AlignCenter)
        layout.addWidget(subtitle)
        
        # Skip break button
        skip_button = QPushButton("Skip Break (Press Space)")
        skip_button.setStyleSheet("""
            QPushButton {
                background-color: rgba(255, 255, 255, 0.1);
                border: 2px solid rgba(255, 255, 255, 0.3);
                border-radius: 25px;
                color: white;
                font-size: 18px;
                padding: 15px 40px;
                margin-top: 20px;
            }
            QPushButton:hover {
                background-color: rgba(255, 255, 255, 0.2);
                border-color: rgba(255, 255, 255, 0.5);
            }
            QPushButton:pressed {
                background-color: rgba(255, 255, 255, 0.3);
            }
        """)
        skip_button.clicked.connect(self.end_break)
        layout.addWidget(skip_button)
        
        self.setLayout(layout)
        
        # Update initial display
        self.update_countdown()
        
        # Enable keyboard shortcuts
        self.setFocusPolicy(Qt.StrongFocus)
        
    def show_fullscreen(self):
        """Show on all displays"""
        self.showFullScreen()
        self.raise_()
        self.activateWindow()
        
    def start_break(self):
        """Start the break countdown"""
        print(f"Starting {self.duration_minutes}-minute break")
        self.timer.start(1000)  # Update every second
        
    def update_countdown(self):
        """Update countdown display"""
        if self.remaining_seconds <= 0:
            self.end_break()
            return
            
        minutes = self.remaining_seconds // 60
        seconds = self.remaining_seconds % 60
        
        # Format time display
        time_text = f"{minutes:02d}:{seconds:02d}"
        self.countdown_label.setText(time_text)
        
        self.remaining_seconds -= 1
        
    def end_break(self):
        """End the break and resume session"""
        self.timer.stop()
        print("Break finished, resuming session")
        self.break_finished.emit()
        self.close()
        
    def keyPressEvent(self, event):
        """Handle keyboard shortcuts"""
        if event.key() == Qt.Key_Space or event.key() == Qt.Key_Escape:
            self.end_break()
        else:
            super().keyPressEvent(event)
            
    def closeEvent(self, event):
        """Clean up when window closes"""
        self.timer.stop()
        event.accept()

class FocusLauncher:
    def __init__(self):
        
        QApplication.setApplicationName("Focus Utility")
        self.app = QApplication(sys.argv)
        self.app.setWindowIcon(get_app_icon())
        
        # Prevent app from quitting when all windows are closed (important for background timers)
        self.app.setQuitOnLastWindowClosed(False)
        
        # Set up graceful cleanup handlers
        def cleanup_handler():
            """Cleanup function called on exit"""
            print("Performing emergency cleanup...")
            try:
                from plugin_system import plugin_manager
                plugin_manager.cleanup_all_plugins()
            except Exception as e:
                print(f"Plugin cleanup error: {e}")
            
            try:
                stop_focus_mode_with_password()
            except Exception as e:
                print(f"Focus mode cleanup error: {e}")
        
        def signal_handler(signum, frame):
            """Handle termination signals"""
            print(f"Received signal {signum}, cleaning up...")
            cleanup_handler()
            sys.exit(1)
        
        # Register cleanup handlers
        atexit.register(cleanup_handler)
        signal.signal(signal.SIGINT, signal_handler)   # Ctrl+C
        signal.signal(signal.SIGTERM, signal_handler)  # Kill signal
        
        # Initialize plugin system
        try:
            from plugin_system import plugin_manager
            # Plugin manager is initialized when imported and will load previously enabled plugins
        except Exception as e:
            print(f"Plugin system initialization error: {e}")
        
    def run(self):
        # NEW STREAMLINED FLOW: Skip mode selector, go directly to todo entry
        streamlined_dialog = StreamlinedTodoDialog()
        if streamlined_dialog.exec_() != QDialog.Accepted:
            print("Session cancelled. Exiting.")
            return
        
        # Get the analyzed goals and AI analysis (includes plugin tasks)
        final_goals = streamlined_dialog.analyzed_goals
        ai_analysis = getattr(streamlined_dialog, 'ai_analysis', None)
        
        # Show session visualization and editing screen
        visualization_dialog = SessionVisualizationDialog(ai_analysis, final_goals)
        if visualization_dialog.exec_() != QDialog.Accepted:
            print("Session cancelled during review. Exiting.")
            return
        
        # Explicitly close dialogs to prevent lingering windows
        streamlined_dialog.close()
        streamlined_dialog.deleteLater()
        visualization_dialog.close() 
        visualization_dialog.deleteLater()
        
        # Use AI analysis to determine session structure
        if ai_analysis and ai_analysis.get('session_structure'):
            session_structure = ai_analysis['session_structure']
            total_duration = ai_analysis.get('total_duration', 60)
            
            print(f"AI analyzed session: {len(session_structure)} section(s), total {total_duration} minutes")
            
            # For multi-section sessions, use the new manager
            if len(session_structure) > 1:
                print("Starting multi-section session")
                
                # Show breathing countdown only once (for first section)
                first_section = session_structure[0]
                countdown = CountdownManager(first_section['mode'], self.app)
                countdown.show()
                
                # Wait for countdown to finish
                wait_timer = QTimer()
                wait_timer.timeout.connect(lambda: self.check_countdown_finished_multi(countdown, wait_timer))
                wait_timer.start(100)
                
                while not countdown.check_countdown_finished():
                    self.app.processEvents()
                    if not countdown.isVisible():
                        break
                
                # Properly close countdown windows
                countdown.close()
                
                # Start multi-section session manager
                session_manager = MultiSectionSessionManager(session_structure, final_goals, self.app)
                session_manager.start_session()
                
                # Keep application running
                self.app.exec_()
                return
            else:
                # Single section - use traditional flow
                first_section = session_structure[0]
                selected_mode = first_section['mode']
                session_duration = first_section['duration_minutes']
        else:
            # Fallback to single section
            selected_mode = "productivity"
            session_duration = 60
            print(f"Using fallback: {selected_mode} mode for {session_duration} minutes")
        
        print(f"Session goals: {len(final_goals)} total goals")
        
        # Traditional single-section flow
        # Show countdown on all displays
        countdown = CountdownManager(selected_mode, self.app)
        countdown.show()
        
        # Wait for countdown to finish using a timer-based approach
        wait_timer = QTimer()
        wait_timer.timeout.connect(lambda: self.check_countdown_finished_multi(countdown, wait_timer))
        wait_timer.start(100)  # Check every 100ms
        
        # Process events while waiting
        while not countdown.check_countdown_finished():
            self.app.processEvents()
            if not countdown.isVisible():
                break
        
        # Properly close countdown windows after breathing countdown finishes
        countdown.close()
        
        # Launch focus mode
        self.launch_focus_mode(selected_mode)
        
        # Define function to start progress tracking after video
        def start_progress_tracking():
            popup_interval = get_popup_interval_setting()
            print(f"DEBUG: Using popup interval: {popup_interval} minutes")
            self.progress_popup = ProgressPopup(session_duration, final_goals, popup_interval=popup_interval, parent_launcher=self, mode=selected_mode)
            
            # Note: AI notification will be sent when user dismisses first progress popup
            
            # Set progress popup reference for plugin system
            try:
                from plugin_system import plugin_manager
                plugin_manager.set_progress_popup_reference(self.progress_popup)
            except Exception as e:
                print(f"Error setting progress popup reference: {e}")
        
        # Play transition video first, then start progress tracking
        self.play_mode_video(selected_mode, start_progress_tracking)
        
        # Keep the application running during the session
        self.app.exec_()
    
    def check_countdown_finished(self, countdown, timer):
        """Helper method to check if countdown is finished"""
        if countdown.countdown_finished or not countdown.isVisible():
            timer.stop()
    
    def check_countdown_finished_multi(self, countdown, timer):
        """Helper method to check if multi-display countdown is finished"""
        if countdown.check_countdown_finished() or not countdown.isVisible():
            timer.stop()
    
    def launch_focus_mode(self, mode):
        """Launch the actual focus mode scripts"""
        try:
            # Change to the script directory
            script_dir = os.path.dirname(os.path.abspath(__file__))
            
            # Clear agent_history.txt at the start of each focus session
            self.clear_agent_history(script_dir)
            os.chdir(script_dir)
            
            # Handle custom modes
            actual_mode = mode
            if mode.startswith('custom/'):
                actual_mode = mode.replace('custom/', '')
                # Verify custom mode files exist
                custom_mode_file = os.path.join('modes', 'custom', f'{actual_mode}.txt')
                custom_hosts_file = os.path.join('hosts', 'custom', f'{actual_mode}_hosts')
                
                if not os.path.exists(custom_mode_file):
                    raise Exception(f"Custom mode file not found: {custom_mode_file}")
                if not os.path.exists(custom_hosts_file):
                    raise Exception(f"Custom hosts file not found: {custom_hosts_file}")
            
            # Start monitoring in background
            subprocess.Popen(['./monitor_active_programs.sh'], 
                           stdout=subprocess.DEVNULL, 
                           stderr=subprocess.DEVNULL)
            
            # Always use full blocking with website blocking
            # Get password (using stored password if available)
            try:
                from password_manager import get_sudo_password
                password = get_sudo_password()
            except ImportError:
                # Fallback to original method if password manager not available
                from PyQt5.QtWidgets import QDialog
                password_dialog = PasswordDialog()
                if password_dialog.exec_() == QDialog.Accepted:
                    password = password_dialog.password
                else:
                    password = None
            
            if password:
                # Create modified script that uses the provided password
                try:
                    self.run_with_password(mode, password)
                    display_name = actual_mode.replace('_', ' ').title() if mode.startswith('custom/') else mode.title()
                    print(f"{display_name} focus mode activated with full blocking!")
                except Exception as e:
                    print(f"Failed to activate focus mode: {e}")
                    return
            else:
                print("Password required for focus mode. Exiting.")
                return
                
        except subprocess.CalledProcessError as e:
            print(f"Error launching focus mode: {e}")
            sys.exit(1)
    
    def clear_agent_history(self, script_dir=None):
        """Clear chat history files at the start of a focus session"""
        try:
            if script_dir is None:
                script_dir = os.path.dirname(os.path.abspath(__file__))
            
            # Clear chat history file
            history_file = os.path.join(script_dir, 'chat_history.txt')
            if os.path.exists(history_file):
                with open(history_file, 'w') as f:
                    f.write('')  # Write empty content to clear the file
            
            print("Agent history cleared for new focus session")
            
        except Exception as e:
            print(f"Warning: Could not clear agent history: {e}")
    
    def run_with_password(self, mode, password):
        """Run the focus mode setup with the provided password"""
        try:
            # Handle custom modes
            actual_mode = mode
            hosts_file = f"hosts/{mode}_hosts"
            if mode.startswith('custom/'):
                actual_mode = mode.replace('custom/', '')
                hosts_file = f"hosts/custom/{actual_mode}_hosts"
            
            # Write mode to file (use actual_mode for consistency)
            print(f"DEBUG: Creating current_mode file for {actual_mode} mode")
            with open('current_mode', 'w') as f:
                f.write(actual_mode)
            
            # Escape password for shell safety
            escaped_password = password.replace('"', '\\"').replace('$', '\\$').replace('`', '\\`')
            
            # Copy hosts file with password
            cmd1 = f'echo "{escaped_password}" | sudo -S cp "{hosts_file}" /etc/hosts 2>/dev/null'
            result1 = subprocess.run(cmd1, shell=True, capture_output=True, text=True)
            if result1.returncode != 0:
                raise Exception("Incorrect password or permission denied")
            
            # Flush DNS cache with password  
            cmd2 = f'echo "{escaped_password}" | sudo -S dscacheutil -flushcache 2>/dev/null'
            subprocess.run(cmd2, shell=True, check=True)
            
            cmd3 = f'echo "{escaped_password}" | sudo -S killall -HUP mDNSResponder 2>/dev/null'
            subprocess.run(cmd3, shell=True, check=True)
            
            # Start kill looper with password (run in background)
            cmd4 = f'echo "{escaped_password}" | sudo -S nohup bash ./kill_looper.sh > /dev/null 2>&1 &'
            subprocess.run(cmd4, shell=True)
            
        except Exception as e:
            print(f"Error setting up focus mode with password: {e}")
            raise
    
    def request_notification_permission(self):
        """Request notification permission from macOS"""
        try:
            # Check if we can send notifications
            test_script = 'display notification "Permission test" with title "Focus Utility"'
            result = subprocess.run(['osascript', '-e', test_script], 
                                  capture_output=True, text=True, timeout=3)
            
            if result.returncode == 0:
                print("Notification permission already granted")
                return True
            else:
                print("Requesting notification permission...")
                # Show a dialog asking user to enable notifications
                permission_script = '''
                display dialog "Focus Utility needs notification permission to remind you about the AI Agent. Please:" & return & return & "1. Open System Settings > Notifications" & return & "2. Find 'Terminal' or 'osascript'" & return & "3. Enable 'Allow Notifications'" & return & return & "Click OK when done, or Cancel to skip." buttons {"Cancel", "OK"} default button "OK" with title "Enable Notifications"
                '''
                subprocess.run(['osascript', '-e', permission_script], check=False)
                return False
                
        except Exception as e:
            print(f"Error checking notification permission: {e}")
            return False

    def send_ai_reminder_notification(self):
        """Send a system notification reminding user about AI assistant"""
        print("🤖 Focus session started! AI Agent is ready - click the Agent button in your progress popup.")
        
        # Try Python-based notification methods
        notification_sent = False
        
        # Method 1: Try using plyer (cross-platform notifications)
        try:
            from plyer import notification
            notification.notify(
                title='🤖 Focus Session Started',
                message='AI Agent is ready! Click the Agent button.',
                timeout=5
            )
            print("✅ Python notification sent successfully")
            notification_sent = True
        except ImportError:
            print("DEBUG: plyer not available, trying pync...")
        except Exception as e:
            print(f"DEBUG: plyer notification failed: {e}")
        
        # Method 2: Try using pync (macOS specific)
        if not notification_sent:
            try:
                import pync
                pync.notify(
                    'AI Agent is ready! Click the Agent button.',
                    title='🤖 Focus Session Started',
                    sound='Glass'
                )
                print("✅ pync notification sent successfully")
                notification_sent = True
            except ImportError:
                print("DEBUG: pync not available, trying PyQt notifications...")
            except Exception as e:
                print(f"DEBUG: pync notification failed: {e}")
        
        # Method 3: Try PyQt5 system tray notification
        if not notification_sent:
            try:
                from PyQt5.QtWidgets import QSystemTrayIcon
                if hasattr(self, 'app') and QSystemTrayIcon.isSystemTrayAvailable():
                    # Create temporary system tray icon for notification
                    tray_icon = QSystemTrayIcon()
                    tray_icon.setIcon(get_app_icon())
                    tray_icon.show()
                    tray_icon.showMessage(
                        "🤖 Focus Session Started",
                        "AI Agent is ready! Click the Agent button.",
                        QSystemTrayIcon.Information,
                        5000  # 5 seconds
                    )
                    print("✅ PyQt system tray notification sent successfully")
                    notification_sent = True
                else:
                    print("DEBUG: System tray not available")
            except Exception as e:
                print(f"DEBUG: PyQt notification failed: {e}")
        
        # Method 4: Fallback to AppleScript (but probably won't work)
        if not notification_sent:
            try:
                result = subprocess.run([
                    'osascript', '-e', 
                    'display notification "AI Agent is ready! Click the Agent button." with title "Focus Started"'
                ], capture_output=True, text=True, timeout=3)
                if result.returncode == 0:
                    print("✅ AppleScript notification sent successfully")
                    notification_sent = True
                else:
                    print(f"DEBUG: AppleScript failed: {result.stderr}")
            except Exception as e:
                print(f"DEBUG: AppleScript notification failed: {e}")
        
        # If all methods failed, show instructions
        if not notification_sent:
            print("💡 To enable visual notifications:")
            print("   pip install plyer  (or)  pip install pync")
            print("   System Settings > Notifications > Terminal (enable)")

    def play_mode_video(self, mode, callback):
        """Play video for mode transition"""
        # Check if video exists before creating window
        script_dir = os.path.dirname(os.path.abspath(__file__))
        video_filename = f"{mode}.mp4"
        video_path = os.path.join(script_dir, "videos", video_filename)
        
        print(f"DEBUG: Checking video for mode '{mode}' at path: {video_path}")
        print(f"DEBUG: VIDEO_SUPPORT = {VIDEO_SUPPORT}")
        print(f"DEBUG: File exists = {os.path.exists(video_path) if video_path else False}")
        
        if VIDEO_SUPPORT and os.path.exists(video_path):
            # Video exists, show it on primary display only
            print(f"Playing transition video for {mode} mode")
            self.current_video = VideoPlayerWindow(mode)
            def cleanup_and_callback():
                # Clean up video reference
                if hasattr(self, 'current_video') and self.current_video:
                    self.current_video.close()
                    self.current_video = None
                callback()
            self.current_video.finished.connect(cleanup_and_callback)
            self.current_video.show()
        else:
            # No video, trigger plugins immediately and skip to callback
            print(f"No video for {mode} mode, proceeding directly to session")
            
            # Trigger plugins since there's no video to do it
            def trigger_plugins_and_callback():
                try:
                    from plugin_system import plugin_manager
                    session_data = {
                        'mode': mode,
                        'start_time': datetime.now(),
                        'trigger_point': 'no_video',
                        'video_active': False
                    }
                    plugin_manager.call_session_start_hooks(session_data)
                    print(f"Triggered session start plugins for {mode} (no video)")
                except Exception as e:
                    print(f"Error triggering plugins (no video): {e}")
                
                callback()
            
            QTimer.singleShot(100, trigger_plugins_and_callback)  # Small delay for smooth transition

class AIAssistantWindow(QWidget):
    """AI Assistant chat window for focus sessions"""
    
    def __init__(self, ai_service, ai_plugin):
        super().__init__()
        self.ai_service = ai_service
        self.ai_plugin = ai_plugin
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('AI Assistant - Focus Helper')
        self.setWindowIcon(get_app_icon())
        self.setFixedSize(500, 600)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
        # Center the window
        self.center_window()
        
        # Modern styling
        self.setStyleSheet("""
            AIAssistantWindow {
                background-color: #f5f5f7;
            }
            QTextEdit {
                background-color: white;
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                padding: 12px;
                font-size: 14px;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            }
            QLineEdit {
                background-color: white;
                border: 2px solid #d1d1d6;
                border-radius: 8px;
                padding: 10px;
                font-size: 14px;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            }
            QLineEdit:focus {
                border-color: #007aff;
            }
            QPushButton {
                background-color: #007aff;
                color: white;
                border: none;
                border-radius: 8px;
                padding: 10px 20px;
                font-size: 14px;
                font-weight: 600;
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            }
            QPushButton:hover {
                background-color: #0056b3;
            }
            QPushButton:pressed {
                background-color: #004080;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        # Title
        title = QLabel("AI Focus Assistant")
        title.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 10px;
        """)
        layout.addWidget(title)
        
        # Chat display using scroll area for better styling control
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        scroll_area.setStyleSheet("""
            QScrollArea {
                border: none;
                background-color: #f5f5f7;
            }
            QScrollArea > QWidget > QWidget {
                background-color: #f5f5f7;
            }
        """)
        
        # Chat container widget
        self.chat_widget = QWidget()
        self.chat_layout = QVBoxLayout(self.chat_widget)
        self.chat_layout.setContentsMargins(10, 10, 10, 10)
        self.chat_layout.setSpacing(8)
        self.chat_layout.addStretch()  # Push messages to top
        
        scroll_area.setWidget(self.chat_widget)
        layout.addWidget(scroll_area)
        
        # Add initial message
        self.add_message("AI", "Hello! I'm your AI assistant. I can help you stay focused and productive during your session.\n\nHow can I help you today?")
        
        # Input section
        input_layout = QHBoxLayout()
        
        self.chat_input = QLineEdit()
        self.chat_input.setPlaceholderText("Type your message here...")
        self.chat_input.returnPressed.connect(self.send_message)
        input_layout.addWidget(self.chat_input)
        
        send_button = QPushButton("Send")
        send_button.clicked.connect(self.send_message)
        input_layout.addWidget(send_button)
        
        layout.addLayout(input_layout)
        self.setLayout(layout)
        
        # Focus on input
        self.chat_input.setFocus()
    
    def center_window(self):
        """Center the window on screen"""
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def send_message(self):
        """Send message to AI and display response"""
        user_input = self.chat_input.text().strip()
        if not user_input:
            return
        
        # Clear input
        self.chat_input.clear()
        
        # Add user message to display
        self.add_message("You", user_input)
        
        # Get AI response
        try:
            from agent import chat
            response, commands_used = chat(self.ai_service, user_input, self.ai_plugin)
            
            # Check for empty response and retry up to 3 times
            retry_count = 0
            max_retries = 3
            while (not response or response.strip() == "") and retry_count < max_retries:
                retry_count += 1
                print(f"DEBUG: Empty AI response, retrying ({retry_count}/{max_retries})")
                response, commands_used = chat(self.ai_service, user_input, self.ai_plugin)
            
            # If still empty after retries, provide fallback message
            if not response or response.strip() == "":
                response = "Sorry, I'm having trouble responding right now. Please try rephrasing your question."
            
            self.add_message("AI", response)
        except Exception as e:
            self.add_message("AI", f"Sorry, I encountered an error: {e}")
        
        # Focus back on input
        self.chat_input.setFocus()
    
    def add_message(self, sender, message):
        """Add a message to the chat display with styled bubbles"""
        # Filter out SYSINFPULL commands from display
        if "SYSINFPULL:" in message:
            # Remove the SYSINFPULL part and any text after it
            message = message.split("SYSINFPULL:")[0].strip()
            # If there's no text left after removing SYSINFPULL, don't display anything
            if not message:
                return
        
        # Escape HTML characters in the message
        import html
        message = html.escape(message).replace('\n', '<br>')
        
        # Get timestamp
        from datetime import datetime
        timestamp = datetime.now().strftime("%H:%M")
        
        # Style based on sender
        if sender == "AI":
            # Blue bubble, left-aligned
            bubble_html = f"""
            <div style="margin: 8px 50px 8px 0px; text-align: left;">
                <div style="
                    background-color: #007aff;
                    color: white;
                    padding: 12px 16px;
                    border-radius: 20px;
                    display: inline-block;
                    max-width: 80%;
                    font-size: 14px;
                    line-height: 1.4;
                    word-wrap: break-word;
                    margin: 6px;
                    drop-shadow: 5px 20px 14px rgba(0,0,0,0.1);
                ">
                    {message}
                </div>
                <div style="font-size: 11px; color: #8E8E93; margin-top: 4px; margin-left: 4px;">
                    {timestamp}
                </div>
            </div>
            """
        else:  # User
            # Grey bubble, right-aligned
            bubble_html = f"""
            <div style="margin: 8px 0px 8px 50px; text-align: right;">
                <div style="
                    background-color: #E5E5EA;
                    color: #000000;
                    padding: 12px 16px;
                    border-radius: 20px;
                    display: inline-block;
                    max-width: 80%;
                    font-size: 14px;
                    line-height: 1.4;
                    word-wrap: break-word;
                    margin: 6px;
                    drop-shadow: 5px 20px 14px rgba(0,0,0,0.1);
                ">
                    {message}
                </div>
                <div style="font-size: 11px; color: #8E8E93; margin-top: 4px; margin-right: 4px;">
                    {timestamp}
                </div>
            </div>
            """
        
        # Get current HTML and append new message
        current_html = self.chat_display.toHtml()
        
        # If this is the first message, start with a clean HTML structure
        if not hasattr(self, '_html_initialized'):
            current_html = """
            <html>
            <head>
                <style>
                    body { 
                        font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                        margin: 0; 
                        padding: 8px;
                        background-color: #f5f5f7;
                        
                    }
                </style>
            </head>
            <body>
            """
            self._html_initialized = True
        
        # Insert the new message before the closing body tag
        if "</body>" in current_html:
            current_html = current_html.replace("</body>", bubble_html + "</body>")
        else:
            current_html += bubble_html
        
        self.chat_display.setHtml(current_html)
        
        # Scroll to bottom
        scrollbar = self.chat_display.verticalScrollBar()
        scrollbar.setValue(scrollbar.maximum())


if __name__ == "__main__":
    try:
        launcher = FocusLauncher()
        launcher.run()
    except ImportError:
        print("PyQt5 not found. Installing...")
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'PyQt5'])
        print("Please run the script again.")