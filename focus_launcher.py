#!/usr/bin/env python3

import sys
import os
import subprocess
import time
from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QComboBox, QPushButton, QFrame, QLineEdit, QDialog, QGraphicsDropShadowEffect)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QPropertyAnimation, QEasingCurve
from PyQt5.QtGui import QFont, QPalette, QColor, QPainter, QPen, QBrush, QPixmap, QRadialGradient
import math

class PasswordDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.password = None
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Authentication Required')
        self.setFixedSize(400, 250)
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
        
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

class CountdownWindow(QWidget):
    def __init__(self, mode):
        super().__init__()
        self.mode = mode
        self.countdown = 15
        self.allowed_apps = self.get_allowed_apps(mode)
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
        # Make fullscreen and remove window decorations
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
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
            self.close()
    
    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.timer.stop()
            self.breathing_circle.animation_timer.stop()
            self.close()
            sys.exit(0)

class FocusSelector(QWidget):
    def __init__(self):
        super().__init__()
        self.selected_mode = None
        self.modes = ['productivity', 'creativity', 'social']
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Focus Mode Selector')
        self.setFixedSize(600, 550)
        self.setWindowFlags(Qt.WindowStaysOnTopHint)
        
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
        self.mode_combo.addItem("Social - Communication and collaboration")
        
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
        
        # Blocking options
        blocking_layout = QVBoxLayout()
        blocking_layout.setSpacing(16)
        
        blocking_label = QLabel("Website Blocking")
        blocking_label.setStyleSheet("""
            font-size: 16px;
            font-weight: 500;
            color: #1d1d1f;
            margin-bottom: 8px;
        """)
        blocking_layout.addWidget(blocking_label)
        
        self.blocking_combo = QComboBox()
        self.blocking_combo.addItem("Apps Only - No password required")
        self.blocking_combo.addItem("Apps + Websites - Password required")
        
        self.blocking_combo.setStyleSheet(self.mode_combo.styleSheet())
        blocking_layout.addWidget(self.blocking_combo)
        
        main_layout.addLayout(blocking_layout)
        
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
    
    def start_focus(self):
        if self.mode_combo.currentIndex() > 0:  # Not "Select a mode..."
            self.selected_mode = self.modes[self.mode_combo.currentIndex() - 1]
            self.use_website_blocking = self.blocking_combo.currentIndex() == 1  # True if "Apps + Websites"
            self.close()
    
    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Return or event.key() == Qt.Key_Enter:
            self.start_focus()

class FocusLauncher:
    def __init__(self):
        self.app = QApplication(sys.argv)
        
    def run(self):
        # Show mode selector
        selector = FocusSelector()
        selector.show()
        self.app.exec_()
        
        if not selector.selected_mode:
            print("No mode selected. Exiting.")
            return
        
        # Show countdown
        countdown = CountdownWindow(selector.selected_mode)
        countdown.show()
        self.app.exec_()
        
        # Launch focus mode
        self.launch_focus_mode(selector.selected_mode, selector.use_website_blocking)
    
    def launch_focus_mode(self, mode, use_website_blocking=False):
        """Launch the actual focus mode scripts"""
        try:
            # Change to the script directory
            script_dir = os.path.dirname(os.path.abspath(__file__))
            os.chdir(script_dir)
            
            # Start monitoring in background
            subprocess.Popen(['./monitor_active_programs.sh'], 
                           stdout=subprocess.DEVNULL, 
                           stderr=subprocess.DEVNULL)
            
            # Choose script based on blocking preference
            if use_website_blocking:
                # Show password dialog
                from PyQt5.QtWidgets import QDialog
                password_dialog = PasswordDialog()
                if password_dialog.exec_() == QDialog.Accepted:
                    password = password_dialog.password
                    # Create modified script that uses the provided password
                    try:
                        self.run_with_password(mode, password)
                        print(f"✅ {mode.title()} focus mode activated with website blocking!")
                    except Exception as e:
                        print(f"❌ Failed to activate focus mode: {e}")
                        return
                else:
                    print("❌ Password required for website blocking. Exiting.")
                    return
            else:
                subprocess.run(['bash', './set_mode_nosudo.sh', mode], check=True)
                print(f"✅ {mode.title()} focus mode activated (apps only, no website blocking)!")
                
        except subprocess.CalledProcessError as e:
            print(f"❌ Error launching focus mode: {e}")
            sys.exit(1)
        except Exception as e:
            print(f"❌ Unexpected error: {e}")
            sys.exit(1)
    
    def run_with_password(self, mode, password):
        """Run the focus mode setup with the provided password"""
        try:
            # Write mode to file
            with open('current_mode', 'w') as f:
                f.write(mode)
            
            # Escape password for shell safety
            escaped_password = password.replace('"', '\\"').replace('$', '\\$').replace('`', '\\`')
            
            # Copy hosts file with password
            cmd1 = f'echo "{escaped_password}" | sudo -S cp "hosts/{mode}_hosts" /etc/hosts 2>/dev/null'
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
            print(f"❌ Error setting up focus mode with password: {e}")
            raise

if __name__ == "__main__":
    try:
        launcher = FocusLauncher()
        launcher.run()
    except ImportError:
        print("PyQt5 not found. Installing...")
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'PyQt5'])
        print("Please run the script again.")