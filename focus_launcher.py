#!/usr/bin/env python3

import sys
import os
import subprocess
import time
from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QComboBox, QPushButton, QFrame, QLineEdit, QDialog, QGraphicsDropShadowEffect,
                             QSpinBox, QTextEdit, QCheckBox, QScrollArea, QProgressBar)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QPropertyAnimation, QEasingCurve, QThread
from PyQt5.QtGui import QFont, QPalette, QColor, QPainter, QPen, QBrush, QPixmap, QRadialGradient
import math
import json
import time as time_module
from datetime import datetime, timedelta
from typing import List

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

def stop_focus_mode_with_password():
    """Stop focus mode, asking for password if needed"""
    try:
        import subprocess
        
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
            # Ask for password for website blocking cleanup
            from PyQt5.QtWidgets import QDialog
            password_dialog = PasswordDialog()
            password_dialog.setWindowTitle('Cleanup Required')
            # Update the message to explain why password is needed
            if password_dialog.exec_() == QDialog.Accepted:
                password = password_dialog.password
                
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
        
        # Always run the basic cleanup (no sudo required)
        subprocess.run(['bash', './stop_focus_mode.sh'], 
                      cwd=os.path.dirname(os.path.abspath(__file__)), 
                      timeout=10)
        
    except Exception as e:
        print(f"Error during focus mode cleanup: {e}")
        # Continue anyway - don't let cleanup failures prevent app exit

class TimePickerDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.duration_minutes = 0
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Session Duration')
        self.setFixedSize(400, 250)
        self.setWindowFlags(Qt.FramelessWindowHint)
        
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
    
    def accept_time(self):
        self.duration_minutes = self.hours_spin.value() * 60 + self.minutes_spin.value()
        if self.duration_minutes > 0:
            self.accept()

class GoalsDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.goals_text = ""
        self.analyzed_goals = []
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Session Goals')
        self.setFixedSize(500, 400)
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
        
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
        self.setFixedSize(500, 400)
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
        
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
        self.setFixedSize(600, 500)
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
        
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
        self.setFixedSize(500, 400)
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
        
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

class ProgressPopup(QWidget):
    def __init__(self, session_duration, goals, popup_interval=1):
        super().__init__()
        self.session_duration = session_duration  # in minutes
        self.goals = goals
        self.popup_interval = popup_interval  # in minutes
        print(f"DEBUG: ProgressPopup initialized with interval: {popup_interval} minutes")
        self.start_time = datetime.now()
        self.completed_goals = set()
        self.app_usage = {}
        self.current_app = ""
        
        self.init_ui()
        self.setup_timers()
    
    def init_ui(self):
        self.setWindowTitle('Focus Session')
        # Dynamic height based on number of goals
        base_height = 360
        num_goals = min(len(self.goals), 3) if self.goals else 0
        if num_goals > 0:
            goal_height = num_goals * 40 + 80  # Space per goal + titles/margins
            total_height = base_height + goal_height
        else:
            total_height = base_height
        
        self.setFixedSize(480, min(total_height, 500))  # Cap at 500px max
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
        
        # Progress bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setFixedHeight(32)  # Made thicker
        self.progress_bar.setFormat("%p%")  # Show percentage on progress bar
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
        self.progress_animation.setDuration(800)  # 0.8 seconds
        self.progress_animation.setEasingCurve(QEasingCurve.OutCubic)
        progress_layout.addWidget(self.progress_bar)
        
        content_layout.addLayout(progress_layout)
        
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
            
            # Show all goals now since we have scrolling
            self.goal_checkboxes = []
            # Dynamic padding based on number of goals
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
        
        # Stop Focus Mode button
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
        
        # Keep Focusing button
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
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
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
        self.app_timer.start(5000)  # Every 5 seconds
        
        # Call session start hooks
        try:
            from plugin_system import plugin_manager
            session_data = {
                'duration': self.session_duration,
                'goals': self.goals,
                'start_time': self.start_time
            }
            plugin_manager.call_session_start_hooks(session_data)
        except Exception as e:
            print(f"Plugin session start hook error: {e}")
        
        # Initial popup
        self.show_popup()
    
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
        elapsed = (datetime.now() - self.start_time).total_seconds() / 60  # minutes
        progress = min(100, (elapsed / self.session_duration) * 100)
        
        # Animate progress bar changes smoothly
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
            # Get current active app
            result = subprocess.run([
                'osascript', '-e', 
                'tell application "System Events" to get name of first application process whose frontmost is true'
            ], capture_output=True, text=True)
            
            current_app = result.stdout.strip()
            
            if current_app and current_app != self.current_app:
                # App changed, record time for previous app
                if self.current_app:
                    if self.current_app in self.app_usage:
                        self.app_usage[self.current_app] += 5  # 5 seconds
                    else:
                        self.app_usage[self.current_app] = 5
                
                self.current_app = current_app
        except:
            pass
    
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
        
        # Call session end hooks
        try:
            from plugin_system import plugin_manager
            session_data = {
                'duration': self.session_duration,
                'goals': self.goals,
                'completed_goals': self.completed_goals,
                'app_usage': self.app_usage,
                'end_time': datetime.now()
            }
            plugin_manager.call_session_end_hooks(session_data)
        except Exception as e:
            print(f"Plugin session end hook error: {e}")
        
        # Show session summary
        summary = SessionSummary(
            session_duration=self.session_duration,
            goals=self.goals,
            completed_goals=self.completed_goals,
            app_usage=self.app_usage
        )
        summary.show()
        summary.raise_()
        summary.activateWindow()
        self.close()
        
        # Kill background processes with password dialog if needed
        stop_focus_mode_with_password()
        
        # Exit the application
        import sys
        sys.exit(0)
    
    def stop_focus_mode(self):
        """Completely stop the focus mode session"""
        # Stop all timers
        if hasattr(self, 'progress_timer'):
            self.progress_timer.stop()
        if hasattr(self, 'popup_timer'):
            self.popup_timer.stop()
        if hasattr(self, 'app_timer'):
            self.app_timer.stop()
        
        # Call session end hooks for early termination
        try:
            from plugin_system import plugin_manager
            session_data = {
                'duration': self.session_duration,
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
        summary = SessionSummary(
            session_duration=self.session_duration,
            goals=self.goals,
            completed_goals=self.completed_goals,
            app_usage=self.app_usage
        )
        summary.show()
        summary.raise_()
        summary.activateWindow()
        
        # Close the popup
        self.close()
        
        # Kill background processes with password dialog if needed
        stop_focus_mode_with_password()
        
        # Exit the application
        import sys
        sys.exit(0)

class SessionSummary(QWidget):
    def __init__(self, session_duration, goals, completed_goals, app_usage):
        super().__init__()
        self.session_duration = session_duration
        self.goals = goals
        self.completed_goals = completed_goals
        self.app_usage = app_usage
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
        # Use normal window flags for better stability on macOS
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_ShowWithoutActivating, False)  # Allow activation
        
        # Close any other plugin dialogs that might be open
        try:
            from plugin_system import plugin_manager
            # Call cleanup on all plugins to close any open dialogs
            for plugin in plugin_manager.loaded_plugins.values():
                if hasattr(plugin, '_active_dialogs'):
                    for dialog in plugin._active_dialogs[:]:  # Copy list to avoid modification during iteration
                        try:
                            dialog.close()
                        except:
                            pass
                    plugin._active_dialogs.clear()
        except Exception as e:
            print(f"Error closing plugin dialogs: {e}")
        
        # Show maximized instead of fullscreen for better stability
        self.showMaximized()
        
        # Black background like countdown
        self.setStyleSheet("background-color: #000000;")
        
        layout = QVBoxLayout()
        layout.setAlignment(Qt.AlignCenter)
        layout.setContentsMargins(50, 50, 50, 50)
        
        # Dynamic title based on completion rate
        title_text = self.get_encouraging_title()
        title = QLabel(title_text)
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            color: #007aff;
            font-size: 48px;
            font-weight: bold;
            margin-bottom: 30px;
        """)
        layout.addWidget(title)
        
        # Stats container
        stats_container = QFrame()
        stats_container.setStyleSheet("""
            QFrame {
                background-color: rgba(255, 255, 255, 10);
                border-radius: 20px;
                padding: 30px;
            }
        """)
        stats_container.setMaximumWidth(800)
        
        stats_layout = QVBoxLayout(stats_container)
        
        # Session duration
        duration_text = f"Session Duration: {self.session_duration} minutes"
        duration_label = QLabel(duration_text)
        duration_label.setAlignment(Qt.AlignCenter)
        duration_label.setStyleSheet("""
            color: #ffffff;
            font-size: 24px;
            margin-bottom: 20px;
        """)
        stats_layout.addWidget(duration_label)
        
        # Goals completion
        if self.goals:
            completed_count = len(self.completed_goals)
            total_count = len(self.goals)
            completion_rate = (completed_count / total_count * 100) if total_count > 0 else 0
            
            goals_text = f"Goals Completed: {completed_count}/{total_count} ({completion_rate:.0f}%)"
            goals_label = QLabel(goals_text)
            goals_label.setAlignment(Qt.AlignCenter)
            goals_label.setStyleSheet("""
                color: #ffffff;
                font-size: 18px;
                margin-bottom: 20px;
            """)
            stats_layout.addWidget(goals_label)
        
        # Top apps used
        if self.app_usage:
            top_apps = sorted(self.app_usage.items(), key=lambda x: x[1], reverse=True)[:5]
            
            apps_title = QLabel("Top Apps Used:")
            apps_title.setAlignment(Qt.AlignCenter)
            apps_title.setStyleSheet("""
                color: #ffffff;
                font-size: 18px;
                font-weight: bold;
                margin-bottom: 10px;
            """)
            stats_layout.addWidget(apps_title)
            
            for app, seconds in top_apps:
                minutes = seconds // 60
                remaining_seconds = seconds % 60
                time_str = f"{minutes}m {remaining_seconds}s" if minutes > 0 else f"{remaining_seconds}s"
                
                app_label = QLabel(f"• {app}: {time_str}")
                app_label.setAlignment(Qt.AlignCenter)
                app_label.setStyleSheet("""
                    color: #ffffff;
                    font-size: 14px;
                    margin-bottom: 5px;
                """)
                stats_layout.addWidget(app_label)
        
        layout.addWidget(stats_container, 0, Qt.AlignCenter)
        
        # Close instruction
        close_label = QLabel("Press ESC to close")
        close_label.setAlignment(Qt.AlignCenter)
        close_label.setStyleSheet("""
            color: #86868b;
            font-size: 16px;
            margin-top: 40px;
        """)
        layout.addWidget(close_label)
        
        self.setLayout(layout)
        
        # Add timer to ensure the window stays visible for at least a few seconds
        self.min_display_timer = QTimer()
        self.min_display_timer.setSingleShot(True)
        self.min_display_timer.timeout.connect(self.enable_close)
        self.can_close = False
        self.min_display_timer.start(2000)  # 2 seconds minimum display time
    
    def enable_close(self):
        """Enable closing after minimum display time"""
        self.can_close = True
    
    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape and self.can_close:
            self.close()
    
    def showEvent(self, event):
        """Override showEvent to ensure proper focus and visibility"""
        super().showEvent(event)
        # Force the window to come to the front and stay there
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
        
        # Initialize plugin system
        try:
            from plugin_system import plugin_manager
            # Plugin manager is initialized when imported and will load previously enabled plugins
        except Exception as e:
            print(f"Plugin system initialization error: {e}")
        
    def run(self):
        # Show mode selector
        selector = FocusSelector()
        selector.show()
        self.app.exec_()
        
        if not selector.selected_mode:
            print("No mode selected. Exiting.")
            return
        
        # Show time picker
        time_picker = TimePickerDialog()
        if time_picker.exec_() != QDialog.Accepted:
            print("No duration selected. Exiting.")
            return
        
        session_duration = time_picker.duration_minutes
        
        # Show goals dialog
        goals_dialog = GoalsDialog()
        if goals_dialog.exec_() != QDialog.Accepted:
            print("No goals specified. Exiting.")
            return
        
        analyzed_goals = goals_dialog.analyzed_goals
        
        # Show goals review dialog 
        goals_review = GoalsReviewDialog(analyzed_goals)
        goals_review.used_ai = getattr(goals_dialog, 'used_ai', False)
        review_result = goals_review.exec_()
        
        if review_result == QDialog.Rejected:
            # User wants to revise goals, go back to goals dialog
            print("User requested to revise goals, restarting goal input process...")
            goals_dialog = GoalsDialog()
            if goals_dialog.exec_() != QDialog.Accepted:
                print("No goals specified on revision. Exiting.")
                return
            
            analyzed_goals = goals_dialog.analyzed_goals
            
            # Show goals review dialog again with new goals
            goals_review = GoalsReviewDialog(analyzed_goals)
            goals_review.used_ai = getattr(goals_dialog, 'used_ai', False)
            review_result = goals_review.exec_()
            
            if review_result == QDialog.Rejected:
                # If user rejects again, exit
                print("Goals revision cancelled. Exiting.")
                return
            elif not goals_review.approved:
                print("Goals review not approved. Exiting.")
                return
        elif not goals_review.approved:
            print("Goals review not approved. Exiting.")
            return
        
        # Show plugin task scanning dialog (generic for all plugins)
        plugin_scan = PluginTaskDialog(analyzed_goals)
        if plugin_scan.exec_() != QDialog.Accepted:
            print("Plugin task scanning cancelled. Exiting.")
            return
        
        # Use final goals (with plugin tasks if any were added)
        final_goals = plugin_scan.final_goals
        
        # Show final goals if plugin tasks were added
        if len(final_goals) > len(analyzed_goals):
            final_review = FinalGoalsDialog(final_goals)
            if final_review.exec_() == QDialog.Rejected:
                # User wants to revise goals, go back to goals dialog
                print("User requested to revise final goals, restarting goal input process...")
                goals_dialog = GoalsDialog()
                if goals_dialog.exec_() != QDialog.Accepted:
                    print("No goals specified on revision. Exiting.")
                    return
                
                analyzed_goals = goals_dialog.analyzed_goals
                
                # Show goals review dialog again with new goals  
                goals_review = GoalsReviewDialog(analyzed_goals)
                goals_review.used_ai = getattr(goals_dialog, 'used_ai', False)
                if goals_review.exec_() != QDialog.Accepted or not goals_review.approved:
                    print("Goals review not approved. Exiting.")
                    return
                
                # Re-run plugin scan with new goals
                plugin_scan = PluginTaskDialog(analyzed_goals)
                if plugin_scan.exec_() != QDialog.Accepted:
                    print("Plugin task scanning cancelled. Exiting.")
                    return
                
                final_goals = plugin_scan.final_goals
        
        # Show countdown
        countdown = CountdownWindow(selector.selected_mode)
        countdown.show()
        self.app.exec_()
        
        # Launch focus mode
        self.launch_focus_mode(selector.selected_mode, selector.use_website_blocking)
        
        # Start progress tracking with final goals
        popup_interval = get_popup_interval_setting()
        print(f"DEBUG: Using popup interval: {popup_interval} minutes")
        self.progress_popup = ProgressPopup(session_duration, final_goals, popup_interval=popup_interval)
        
        # Set progress popup reference for plugin system
        try:
            from plugin_system import plugin_manager
            plugin_manager.set_progress_popup_reference(self.progress_popup)
        except Exception as e:
            print(f"Error setting progress popup reference: {e}")
        
        # Keep the application running during the session
        self.app.exec_()
    
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
                        print(f"{mode.title()} focus mode activated with website blocking!")
                    except Exception as e:
                        print(f"Failed to activate focus mode: {e}")
                        return
                else:
                    print("Password required for website blocking. Exiting.")
                    return
            else:
                subprocess.run(['bash', './set_mode_nosudo.sh', mode], check=True)
                print(f"{mode.title()} focus mode activated (apps only, no website blocking)!")
                
        except subprocess.CalledProcessError as e:
            print(f"Error launching focus mode: {e}")
            sys.exit(1)
        except Exception as e:
            print(f"Unexpected error: {e}")
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
            print(f"Error setting up focus mode with password: {e}")
            raise

if __name__ == "__main__":
    try:
        launcher = FocusLauncher()
        launcher.run()
    except ImportError:
        print("PyQt5 not found. Installing...")
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'PyQt5'])
        print("Please run the script again.")