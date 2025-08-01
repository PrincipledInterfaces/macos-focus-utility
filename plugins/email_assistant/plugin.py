#!/usr/bin/env python3

import os
import sys
import json
import imaplib
import email
import requests
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
from PyQt5.QtCore import QTimer, QObject, pyqtSignal, QThread, pyqtSignal as Signal, Qt
from PyQt5.QtWidgets import QMessageBox, QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QLineEdit, QTextEdit, QCheckBox, QComboBox, QWidget
from PyQt5.QtGui import QPixmap, QIcon

# Add parent directory to path to import plugin_system
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from plugin_system import PluginBase


class EmailConfigDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.email_config = {}
        self.email_providers = {
            'Gmail': {'server': 'imap.gmail.com', 'port': 993, 'ssl': True},
            'Outlook/Hotmail': {'server': 'outlook.office365.com', 'port': 993, 'ssl': True},
            'Yahoo Mail': {'server': 'imap.mail.yahoo.com', 'port': 993, 'ssl': True},
            'iCloud Mail': {'server': 'imap.mail.me.com', 'port': 993, 'ssl': True},
            'AOL Mail': {'server': 'imap.aol.com', 'port': 993, 'ssl': True},
            'ProtonMail': {'server': 'imap.protonmail.com', 'port': 993, 'ssl': True},
            'Zoho Mail': {'server': 'imap.zoho.com', 'port': 993, 'ssl': True},
            'GMX': {'server': 'imap.gmx.com', 'port': 993, 'ssl': True},
            'Mail.com': {'server': 'imap.mail.com', 'port': 993, 'ssl': True},
            'Fastmail': {'server': 'imap.fastmail.com', 'port': 993, 'ssl': True},
            'Other': {'server': '', 'port': 993, 'ssl': True}
        }
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Email Configuration')
        self.setFixedSize(550, 450)
        
        # Ensure window comes to front when opened
        self.activateWindow()
        self.raise_()
        
        layout = QVBoxLayout()
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Title
        title = QLabel("Email Configuration")
        title.setStyleSheet("font-size: 16px; font-weight: bold; margin-bottom: 10px;")
        layout.addWidget(title)
        
        # Provider selection
        provider_layout = QHBoxLayout()
        provider_layout.addWidget(QLabel("Email Provider:"))
        self.provider_combo = QComboBox()
        self.provider_combo.addItems(list(self.email_providers.keys()))
        self.provider_combo.currentTextChanged.connect(self.on_provider_changed)
        provider_layout.addWidget(self.provider_combo)
        layout.addLayout(provider_layout)
        
        # Email field
        email_layout = QHBoxLayout()
        email_layout.addWidget(QLabel("Email Address:"))
        self.email_input = QLineEdit()
        self.email_input.setPlaceholderText("your.email@example.com")
        email_layout.addWidget(self.email_input)
        layout.addLayout(email_layout)
        
        # Password field
        password_layout = QHBoxLayout()
        password_layout.addWidget(QLabel("Password:"))
        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.Password)
        self.password_input.setPlaceholderText("App password or regular password")
        password_layout.addWidget(self.password_input)
        layout.addLayout(password_layout)
        
        # Custom server fields (hidden by default)
        self.custom_server_widget = QWidget()
        custom_layout = QVBoxLayout(self.custom_server_widget)
        custom_layout.setContentsMargins(0, 0, 0, 0)
        
        server_layout = QHBoxLayout()
        server_layout.addWidget(QLabel("IMAP Server:"))
        self.server_input = QLineEdit()
        self.server_input.setPlaceholderText("imap.example.com")
        server_layout.addWidget(self.server_input)
        custom_layout.addLayout(server_layout)
        
        layout.addWidget(self.custom_server_widget)
        self.custom_server_widget.hide()
        
        # Help text that updates based on provider
        self.help_text = QLabel()
        self.help_text.setWordWrap(True) 
        self.help_text.setStyleSheet("font-size: 11px; color: #666; margin: 10px 0px; padding: 10px; background-color: #f5f5f5; border-radius: 5px;")
        layout.addWidget(self.help_text)
        
        # Set initial help text
        self.on_provider_changed()
        
        # Buttons
        button_layout = QHBoxLayout()
        
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        
        test_btn = QPushButton("Test Connection")
        test_btn.clicked.connect(self.test_connection)
        
        save_btn = QPushButton("Save")
        save_btn.clicked.connect(self.save_config)
        save_btn.setDefault(True)
        
        button_layout.addWidget(cancel_btn)
        button_layout.addWidget(test_btn)
        button_layout.addWidget(save_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
    
    def on_provider_changed(self):
        """Update help text and show/hide custom server fields based on provider"""
        provider = self.provider_combo.currentText()
        
        if provider == 'Other':
            self.custom_server_widget.show()
            self.help_text.setText("Enter your email provider's IMAP server settings. Contact your email provider if you're unsure about these settings.")
        else:
            self.custom_server_widget.hide()
            
            help_texts = {
                'Gmail': "For Gmail, you need to enable 2-factor authentication and create an 'App Password'. Go to Google Account Settings → Security → 2-Step Verification → App passwords.",
                'Outlook/Hotmail': "IMPORTANT: Microsoft has largely disabled basic auth. You likely need an app password even without 2FA. Go to account.microsoft.com → Security → Advanced security options → App passwords. If that option isn't available, your account may not support IMAP.",
                'Yahoo Mail': "Use your regular Yahoo password or create an app password if you have 2-factor authentication enabled.",
                'iCloud Mail': "Use your Apple ID password or create an app-specific password if you have 2-factor authentication enabled.",
                'AOL Mail': "Use your regular AOL password or create an app password if you have 2-factor authentication enabled.",
                'ProtonMail': "Use your ProtonMail Bridge credentials. You need to have ProtonMail Bridge installed and running."
            }
            
            self.help_text.setText(help_texts.get(provider, "Enter your email credentials to connect your account."))
        
        # Resize dialog to fit content
        self.adjustSize()
    
    def test_connection(self):
        """Test the email connection"""
        email_addr = self.email_input.text().strip()
        password = self.password_input.text().strip()
        provider = self.provider_combo.currentText()
        
        if not all([email_addr, password]):
            QMessageBox.warning(self, "Missing Information", "Please enter your email address and password.")
            return
        
        # Get server info
        if provider == 'Other':
            server = self.server_input.text().strip()
            if not server:
                QMessageBox.warning(self, "Missing Information", "Please enter the IMAP server for your email provider.")
                return
        else:
            server = self.email_providers[provider]['server']
        
        try:
            # Test IMAP connection with detailed error reporting
            print(f"Testing connection to {provider} ({server}) for {email_addr}")
            mail = imaplib.IMAP4_SSL(server, 993)  # Explicitly specify port
            print(f"SSL connection established to {server}")
            
            login_result = mail.login(email_addr, password)
            print(f"Login result: {login_result}")
            
            select_result = mail.select('inbox')
            print(f"Inbox select result: {select_result}")
            
            mail.logout()
            print("Connection test successful")
            
            QMessageBox.information(self, "Success", f"Successfully connected to {provider}!\nEmail: {email_addr}")
        except Exception as e:
            error_msg = str(e)
            print(f"Connection error: {error_msg}")
            
            if "authentication failed" in error_msg.lower() or "login failed" in error_msg.lower():
                QMessageBox.critical(self, "Authentication Failed", 
                                   f"Login failed for {provider}.\n\n{self.get_detailed_auth_help(provider)}")
            elif "timed out" in error_msg.lower():
                QMessageBox.critical(self, "Connection Timeout", 
                                   f"Connection to {provider} timed out.\n\nThis might be due to:\n• Firewall blocking the connection\n• Incorrect server settings\n• Network issues")
            elif "certificate" in error_msg.lower():
                QMessageBox.critical(self, "SSL Certificate Error", 
                                   f"SSL certificate error for {provider}.\n\nTry:\n• Check your internet connection\n• Verify the server address is correct")
            else:
                QMessageBox.critical(self, "Connection Failed", f"Failed to connect to {provider}:\n\n{error_msg}\n\nServer: {server}\nPort: 993")
    
    def get_detailed_auth_help(self, provider):
        """Get detailed authentication help for connection failures"""
        if provider == "Outlook/Hotmail":
            return """Common Outlook/Hotmail issues:

1. Two-Factor Authentication:
   • If you have 2FA enabled, you MUST create an app password
   • Go to account.microsoft.com → Security → Advanced security options
   • Select "Create a new app password"
   • Use the app password instead of your regular password

2. Basic Authentication:
   • Microsoft is disabling basic auth for many accounts
   • You may need to enable "Less secure app access" (if available)
   • Or use an app password even without 2FA

3. Account Type Issues:
   • Work/School accounts may not support IMAP
   • Personal accounts should work with proper settings

4. Alternative: Try "Other" provider with:
   • Server: outlook.office365.com
   • Port: 993
   • SSL: Yes"""
        
        elif provider == "Gmail":
            return """Gmail requires App Passwords:

1. Enable 2-Factor Authentication:
   • Go to myaccount.google.com
   • Security → 2-Step Verification → Turn on

2. Create App Password:
   • Security → 2-Step Verification → App passwords
   • Select "Mail" and your device
   • Use the generated 16-character password

3. Account Settings:
   • Make sure IMAP is enabled in Gmail settings
   • Settings → Forwarding and POP/IMAP → Enable IMAP"""
        
        elif provider == "Yahoo Mail":
            return """Yahoo Mail authentication:

1. Generate App Password:
   • Go to account.yahoo.com
   • Account Security → Generate app password
   • Select "Other app" and name it
   • Use the generated password

2. Account Settings:
   • Make sure IMAP access is enabled
   • Some Yahoo accounts require paid subscription for IMAP"""
        
        else:
            help_texts = {
                'Gmail': "• Enable 2-factor authentication\n• Generate an App Password in Google Account settings\n• Use the App Password, not your regular password",
                'Outlook/Hotmail': "• Try your regular Microsoft password first\n• If that fails, create an app password in Microsoft Account settings",
                'Yahoo Mail': "• Try your regular Yahoo password first\n• If that fails, create an app password in Yahoo Account settings",
                'iCloud Mail': "• Try your Apple ID password first\n• If that fails, create an app-specific password in Apple ID settings",
                'AOL Mail': "• Try your regular AOL password first\n• If that fails, create an app password in AOL Account settings",
                'ProtonMail': "• Install and configure ProtonMail Bridge\n• Use Bridge credentials, not your web login"
            }
            return help_texts.get(provider, "• Check your email provider's help documentation for IMAP settings")
    
    def save_config(self):
        """Save the email configuration"""
        email_addr = self.email_input.text().strip()
        password = self.password_input.text().strip()
        provider = self.provider_combo.currentText()
        
        if not all([email_addr, password]):
            QMessageBox.warning(self, "Missing Information", "Please enter your email address and password.")
            return
        
        # Get server info
        if provider == 'Other':
            server = self.server_input.text().strip()
            if not server:
                QMessageBox.warning(self, "Missing Information", "Please enter the IMAP server for your email provider.")
                return
        else:
            server = self.email_providers[provider]['server']
        
        self.email_config = {
            'email': email_addr,
            'password': password,
            'server': server,
            'provider': provider,
            'auth_type': 'manual'
        }
        self.accept()

class EmailNotificationDialog(QDialog):
    def __init__(self, email_task, email_summary, parent=None):
        super().__init__(parent)
        self.email_task = email_task
        self.email_summary = email_summary
        self.add_to_checklist = False
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Important Email Detected')
        self.setFixedSize(500, 300)
        self.setWindowFlags(Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint)
        
        # Add shadow effect
        from PyQt5.QtWidgets import QGraphicsDropShadowEffect
        from PyQt5.QtGui import QColor
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
        title = QLabel("Important Email")
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("""
            font-size: 18px;
            font-weight: 600;
            color: #1d1d1f;
        """)
        layout.addWidget(title)
        
        # Email summary
        summary_label = QLabel(f"From: {self.email_summary.get('from', 'Unknown')}")
        summary_label.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
            margin-bottom: 10px;
        """)
        layout.addWidget(summary_label)
        
        # Task description
        task_label = QLabel(f"Task: {self.email_task}")
        task_label.setWordWrap(True)
        task_label.setStyleSheet("""
            font-size: 16px;
            color: #1d1d1f;
            font-weight: 500;
            padding: 15px;
            background-color: #f5f5f7;
            border-radius: 10px;
            line-height: 1.4;
        """)
        layout.addWidget(task_label)
        
        # Question
        question = QLabel("Would you like to add this task to your focus session checklist?")
        question.setAlignment(Qt.AlignCenter)
        question.setWordWrap(True)
        question.setStyleSheet("""
            font-size: 14px;
            color: #86868b;
        """)
        layout.addWidget(question)
        
        # Buttons
        button_layout = QHBoxLayout()
        button_layout.setSpacing(12)
        
        dismiss_btn = QPushButton("Dismiss")
        dismiss_btn.clicked.connect(self.dismiss_notification)
        dismiss_btn.setStyleSheet("""
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
        
        add_btn = QPushButton("Add to Checklist")
        add_btn.clicked.connect(self.add_to_checklist_action)
        add_btn.setDefault(True)
        add_btn.setStyleSheet("""
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
        
        button_layout.addWidget(dismiss_btn)
        button_layout.addWidget(add_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
    
    def center_window(self):
        from PyQt5.QtWidgets import QDesktopWidget
        qr = self.frameGeometry()
        cp = QDesktopWidget().availableGeometry().center()
        qr.moveCenter(cp)
        self.move(qr.topLeft())
    
    def dismiss_notification(self):
        try:
            self.add_to_checklist = False
            self.accept()
        except Exception as e:
            print(f"Error dismissing notification: {e}")
            self.close()
    
    def add_to_checklist_action(self):
        try:
            self.add_to_checklist = True
            self.accept()
        except Exception as e:
            print(f"Error accepting notification: {e}")
            self.close()

class EmailTaskDialog(QDialog):
    def __init__(self, email_summaries, parent=None):
        super().__init__(parent)
        self.email_summaries = email_summaries
        self.selected_tasks = []
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle('Important Emails Found')
        self.setFixedSize(600, 400)
        
        layout = QVBoxLayout()
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Title
        title = QLabel("Important emails require your attention")
        title.setStyleSheet("font-size: 16px; font-weight: bold; margin-bottom: 10px;")
        layout.addWidget(title)
        
        # Email list
        self.checkboxes = []
        for email_summary in self.email_summaries:
            checkbox = QCheckBox()
            checkbox.setChecked(True)  # Default to checked
            checkbox.setText(f"From: {email_summary['from']} - {email_summary['task']}")
            checkbox.setStyleSheet("margin: 5px 0px;")
            layout.addWidget(checkbox)
            self.checkboxes.append((checkbox, email_summary))
        
        # Buttons
        button_layout = QHBoxLayout()
        
        skip_btn = QPushButton("Skip All")
        skip_btn.clicked.connect(self.reject)
        
        add_btn = QPushButton("Add Selected Tasks")
        add_btn.clicked.connect(self.add_selected)
        add_btn.setDefault(True)
        
        button_layout.addWidget(skip_btn)
        button_layout.addWidget(add_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
    
    def add_selected(self):
        """Add selected email tasks"""
        self.selected_tasks = []
        for checkbox, email_summary in self.checkboxes:
            if checkbox.isChecked():
                self.selected_tasks.append(email_summary['task'])
        self.accept()

class EmailSignalEmitter(QObject):
    """Separate signal emitter to avoid metaclass conflicts"""
    email_notification = pyqtSignal(str, str)  # title, message

class Plugin(PluginBase):
    """Email Assistant Plugin - Analyzes emails and suggests tasks"""
    
    def __init__(self):
        super().__init__()
        # Create signal emitter separately to avoid metaclass conflict
        self.signal_emitter = EmailSignalEmitter()
        
        self.name = "Email Assistant"
        self.version = "1.0.0"
        self.description = "Analyzes important emails and suggests tasks"
        
        self.email_config = {}
        self.config_file = os.path.join(os.path.dirname(__file__), 'email_config.json')
        self.monitoring_thread = None
        self.should_monitor = False
        self.session_active = False
        
        # Track processed emails to avoid duplicate notifications
        self.processed_emails = set()  # Track by subject + from combination
        
        # Reference to current email dialog to prevent garbage collection
        self.current_email_dialog = None
        
        # Timer for periodic email checks during session
        self.email_timer = QTimer()
        self.email_timer.timeout.connect(self.check_new_emails)
        self.email_timer.setSingleShot(False)  # Ensure it repeats
    
    def initialize(self) -> bool:
        """Initialize the email plugin"""
        try:
            self.load_config()
            
            # Plugin initializes successfully even without email config
            # Configuration will be prompted when actually needed
            print(f"Email plugin initialized. Config available: {bool(self.email_config)}")
            return True
        except Exception as e:
            print(f"Email plugin initialization failed: {e}")
            return False
    
    def configure_email(self):
        """Show email configuration dialog"""
        dialog = EmailConfigDialog()
        
        if dialog.exec_() == QDialog.Accepted:
            self.email_config = dialog.email_config
            self.save_config()
            provider = self.email_config.get('provider', 'Unknown')
            email = self.email_config.get('email', 'unknown')
            print(f"Email configuration saved: {provider} account for {email}")
    
    def load_config(self):
        """Load email configuration from file"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    self.email_config = json.load(f)
        except Exception as e:
            print(f"Error loading email config: {e}")
            self.email_config = {}
    
    def save_config(self):
        """Save email configuration to file"""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.email_config, f, indent=2)
        except Exception as e:
            print(f"Error saving email config: {e}")
    
    def get_recent_emails(self, hours=2) -> List[Dict[str, Any]]:
        """Get recent emails from the last N hours"""
        if not self.email_config:
            print("No email config available")
            return []
        
        try:
            server = self.email_config['server']
            email_addr = self.email_config['email']
            password = self.email_config['password']
            
            print(f"Connecting to {server} for {email_addr}")
            mail = imaplib.IMAP4_SSL(server, 993)
            print("SSL connection established")
            
            # IMAP login with password/app password
            login_result = mail.login(email_addr, password)
            print(f"Login successful: {login_result}")
            
            select_result = mail.select('inbox')
            print(f"Inbox selected: {select_result}")
            
            # Search for emails from the last N hours
            since_date = (datetime.now() - timedelta(hours=hours)).strftime('%d-%b-%Y')
            print(f"Searching for emails since: {since_date}")
            result, messages = mail.search(None, f'(SINCE "{since_date}")')
            
            emails = []
            if result == 'OK':
                message_ids = messages[0].split() if messages[0] else []
                print(f"Found {len(message_ids)} recent emails")
                
                # Get the last 10 emails maximum
                for msg_id in message_ids[-10:]:
                    try:
                        result, msg_data = mail.fetch(msg_id, '(RFC822)')
                        if result == 'OK' and msg_data[0] and len(msg_data[0]) > 1:
                            email_body = msg_data[0][1]
                            email_message = email.message_from_bytes(email_body)
                            
                            # Extract email details
                            subject = email_message['Subject'] or 'No Subject'
                            from_addr = email_message['From'] or 'Unknown Sender'
                            date_str = email_message['Date'] or ''
                            
                            # Get email body
                            body = self.extract_email_body(email_message)
                            
                            emails.append({
                                'subject': subject,
                                'from': from_addr,
                                'date': date_str,
                                'body': body[:2000]  # Increased to 2000 chars for better content analysis
                            })
                            print(f"Processed email: {subject[:50]}...")
                    except Exception as email_error:
                        print(f"Error processing individual email: {email_error}")
                        continue
            else:
                print(f"Email search failed: {result}")
            
            mail.logout()
            print(f"Successfully retrieved {len(emails)} emails")
            return emails
            
        except Exception as e:
            print(f"Error fetching emails: {e}")
            import traceback
            traceback.print_exc()
            return []
    
    def extract_email_body(self, email_message) -> str:
        """Extract the body text from an email message"""
        try:
            raw_body = ""
            if email_message.is_multipart():
                for part in email_message.walk():
                    if part.get_content_type() == "text/plain":
                        raw_body = part.get_payload(decode=True).decode('utf-8', errors='ignore')
                        break
            else:
                raw_body = email_message.get_payload(decode=True).decode('utf-8', errors='ignore')
            
            # Clean the extracted body text
            return self.clean_email_body(raw_body)
        except:
            return ""
        return ""
    
    def clean_email_body(self, body_text: str) -> str:
        """Clean email body text by removing URLs, tracking codes, and embedded content"""
        if not body_text:
            return ""
        
        import re
        
        # Remove URLs (http/https links)
        body_text = re.sub(r'https?://[^\s<>"\']+', '', body_text, flags=re.IGNORECASE)
        
        # Remove email tracking links and UTM parameters
        body_text = re.sub(r'[^\s]*\.(com|net|org|edu|gov|io|co)/[^\s<>"\']*', '', body_text, flags=re.IGNORECASE)
        
        # Remove HubSpot and other tracking links
        body_text = re.sub(r'[^\s]*hubspotlinks[^\s<>"\']*', '', body_text, flags=re.IGNORECASE)
        body_text = re.sub(r'[^\s]*\.eu1\.[^\s<>"\']*', '', body_text, flags=re.IGNORECASE)
        
        # Remove Microsoft Office embedded codes
        body_text = re.sub(r'<[^>]*>', '', body_text)  # HTML tags
        body_text = re.sub(r'\[cid:[^\]]*\]', '', body_text)  # Content-ID references
        body_text = re.sub(r'=\w{2}', '', body_text)  # Quoted-printable encoding artifacts
        
        # Remove common email signature patterns
        body_text = re.sub(r'--+\s*\n.*', '', body_text, flags=re.DOTALL)  # Signature separator
        body_text = re.sub(r'Sent from my \w+.*\n?', '', body_text, flags=re.IGNORECASE)
        
        # Remove unsubscribe and footer links
        body_text = re.sub(r'unsubscribe.*\n?', '', body_text, flags=re.IGNORECASE)
        body_text = re.sub(r'this email was sent.*\n?', '', body_text, flags=re.IGNORECASE)
        body_text = re.sub(r'view.*in.*browser.*\n?', '', body_text, flags=re.IGNORECASE)
        
        # Remove excessive whitespace and empty lines
        body_text = re.sub(r'\n\s*\n\s*\n', '\n\n', body_text)  # Multiple empty lines to double
        body_text = re.sub(r'[ \t]+', ' ', body_text)  # Multiple spaces to single
        
        # Remove common marketing/tracking text patterns
        tracking_patterns = [
            r'pixel.*tracking',
            r'open.*rate',
            r'click.*through',
            r'campaign.*id',
            r'utm_[a-z]+=[^\s&]*',
            r'track.*click',
            r'email.*analytics',
        ]
        
        for pattern in tracking_patterns:
            body_text = re.sub(pattern, '', body_text, flags=re.IGNORECASE)
        
        # Clean up and return
        return body_text.strip()
    
    def analyze_email_importance(self, email_data: Dict[str, Any]) -> Optional[str]:
        """Analyze if an email is important and extract a task using Groq AI"""
        print(f"DEBUG: Analyzing email from {email_data['from']}")
        print(f"DEBUG: Subject: {email_data['subject']}")
        print(f"DEBUG: Body preview: {email_data['body'][:100]}...")
        
        # Quick filter for obviously automated emails
        from_addr = email_data['from'].lower()
        automated_senders = ['noreply', 'no-reply', 'donotreply', 'notification', 'automated', 'system', 'alert', 'marketing']
        is_automated = any(sender in from_addr for sender in automated_senders)
        
        if is_automated:
            print(f"DEBUG: Skipping automated email from {email_data['from']}")
            return None
        
        # Use Groq AI to analyze the email
        groq_analysis = ""

        groq_analysis = self.analyze_email_with_groq(email_data)
        if groq_analysis and groq_analysis != "NO_ACTION":
            print(f"DEBUG: Groq AI analysis result: {groq_analysis}")
            return groq_analysis
        
        if not groq_analysis:
            # Fallback to simplified keyword-based analysis if Groq fails
            print("DEBUG: Groq AI analysis failed, using fallback")
            return self.fallback_email_analysis(email_data)
    
    def analyze_email_with_groq(self, email_data: Dict[str, Any]) -> Optional[str]:
        """Use Groq AI to analyze email and extract actionable task"""
        try:
            # Load Groq API key
            groq_key = self.load_groq_api_key()
            if not groq_key:
                print("No Groq API key found for email analysis")
                return None
            
            # Prepare email content for analysis
            sender_name = self.extract_sender_name(email_data['from'])
            subject = email_data['subject']
            body = email_data['body'][:1500]  # Limit body length for API
            
            # Create prompt for email analysis
            prompt = f"""Analyze this email and determine if it requires action. If it does, extract key specific, actionable tasks.

Email from: {sender_name}
Subject: {subject}
Body: {body}

Instructions:
1. First determine if this email requires any action from the recipient
2. If NO action needed, respond with exactly: "NO_ACTION"
3. If action IS needed, respond with a single, specific task starting with an action verb
4. Make the task clear and concise (under 100 characters)
5. Include relevant deadlines or context if mentioned
6. If the email falls under spam, marketing (such as anything mentioning discounts or sales, or anything reccomending a purchase), or automated notifications, respond with "NO_ACTION"

Examples of good responses:
- "Review the quarterly budget proposal and provide feedback by Friday"
- "Schedule a meeting with John to discuss the project timeline" 
- "Complete the client onboarding form and return it"
- "Approve the design mockups for the new website"

Examples that should return "NO_ACTION":
- Marketing emails or promotions
- Automated notifications

Response:"""
            
            url = "https://api.groq.com/openai/v1/chat/completions"
            headers = {
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {groq_key}'
            }
            
            data = {
                "model": "llama-3.3-70b-versatile",
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 150,
                "temperature": 0.1  # Low temperature for consistent results
            }
            
            print("Analyzing email with Groq AI...")
            response = requests.post(url, headers=headers, json=data, timeout=20)
            
            if response.status_code == 200:
                result = response.json()
                ai_response = result['choices'][0]['message']['content'].strip()
                print(f"Groq AI raw response: {ai_response}")
                
                # Check if AI determined no action is needed
                if "NO_ACTION" in ai_response.upper():
                    print("Groq AI determined no action needed")
                    return "NO_ACTION"
                
                # Clean and validate the response
                cleaned_task = ai_response.strip()
                if len(cleaned_task) > 5 and len(cleaned_task) < 300:  # Reasonable task length
                    return cleaned_task
                else:
                    print(f"Groq response too short/long: {len(cleaned_task)} chars")
                    return None
            else:
                print(f"Groq API error: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            print(f"Groq email analysis failed: {e}")
            return None
    
    def load_groq_api_key(self) -> Optional[str]:
        """Load Groq API key from the main application directory"""
        try:
            # Look for API key in the main application directory
            main_app_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
            key_file = os.path.join(main_app_dir, 'groq_api_key.txt')
            
            if os.path.exists(key_file):
                with open(key_file, 'r') as f:
                    api_key = f.read().strip()
                    if api_key and api_key != 'gsk-your-groq-api-key-here':
                        return api_key
        except Exception as e:
            print(f"Error reading Groq API key file: {e}")
        
        # Fallback to environment variable
        return os.environ.get('GROQ_API_KEY')
    
    def fallback_email_analysis(self, email_data: Dict[str, Any]) -> Optional[str]:
        """Simplified fallback analysis when Groq AI is unavailable"""
        subject = email_data['subject'].lower()
        body = email_data['body'].lower()
        sender_name = self.extract_sender_name(email_data['from'])
        
        # Simple keyword-based importance check
        urgent_keywords = ['urgent', 'asap', 'deadline', 'due', 'important', 'critical']
        action_keywords = ['please', 'can you', 'review', 'approve', 'complete', 'need you to']
        
        has_urgent = any(keyword in subject or keyword in body for keyword in urgent_keywords)
        has_action = any(keyword in subject or keyword in body for keyword in action_keywords)
        has_question = '?' in subject or '?' in body
        
        if has_urgent or has_action or has_question:
            # Generate simple task
            if 'review' in body:
                return f"Review request from {sender_name}: {email_data['subject']}"
            elif 'meeting' in body or 'call' in body:
                return f"Schedule meeting with {sender_name}: {email_data['subject']}"
            elif has_question:
                return f"Respond to {sender_name}: {email_data['subject']}"
            else:
                return f"Follow up with {sender_name}: {email_data['subject']}"
        
        return None
    
    
    def extract_sender_name(self, from_address: str) -> str:
        """Extract sender name from email address"""
        # Handle formats like "John Doe <john@example.com>" or just "john@example.com"
        if '<' in from_address:
            name_part = from_address.split('<')[0].strip()
            if name_part and not '@' in name_part:
                return name_part.strip('"').strip("'")
        
        # Extract name from email address (before @)
        email_part = from_address.split('<')[-1].replace('>', '').strip()
        username = email_part.split('@')[0]
        
        # Convert username to readable name (replace dots/underscores with spaces, capitalize)
        readable_name = username.replace('.', ' ').replace('_', ' ').replace('-', ' ')
        return ' '.join(word.capitalize() for word in readable_name.split())
    
    def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
        """Hook called after goals are analyzed - check for important emails"""
        if not self.email_config:
            return goals
        
        try:
            # Get recent emails
            recent_emails = self.get_recent_emails(hours=4)  # Check last 4 hours
            
            # Analyze emails for importance
            important_email_tasks = []
            for email_data in recent_emails:
                # Create unique identifier for this email
                email_id = f"{email_data['from']}:{email_data['subject']}:{email_data.get('date', '')}"
                
                # Mark this email as processed during initial analysis - THIS IS KEY
                # All emails checked during initial analysis should be marked as processed
                # regardless of whether they generated tasks or not
                self.processed_emails.add(email_id)
                print(f"DEBUG: Marking email as processed during initial analysis: {email_data['subject'][:50]}")
                
                task = self.analyze_email_importance(email_data)
                if task and task != "NO_ACTION":
                    # Format task for inclusion in goals list
                    formatted_task = f"• Email: {task}"
                    important_email_tasks.append(formatted_task)
                    print(f"DEBUG: Added email task to initial goals: {task}")
                else:
                    print(f"DEBUG: Email not important or no action needed during initial analysis")
            
            print(f"DEBUG: Total emails marked as processed during initial analysis: {len(self.processed_emails)}")
            
            # Return goals with email tasks appended for the plugin dialog to handle
            return goals + important_email_tasks
            
        except Exception as e:
            print(f"Error in email goals analysis: {e}")
        
        return goals
    
    def on_session_start(self, session_data: Dict[str, Any]):
        """Hook called when session starts - begin email monitoring"""
        print("DEBUG: Email plugin session_start hook called")
        print(f"DEBUG: Email config available: {bool(self.email_config)}")
        print(f"DEBUG: Email config details: {list(self.email_config.keys()) if self.email_config else 'None'}")
        
        self.session_active = True
        
        # DON'T clear processed emails at session start - keep the ones from initial analysis
        # This prevents asking about the same emails again during the session
        print(f"DEBUG: Keeping {len(self.processed_emails)} emails marked as processed from initial analysis")
        
        # Start periodic email checking every 2 minutes during session
        print("DEBUG: Starting email monitoring timer (2 minute intervals)")
        self.email_timer.start(2 * 60 * 1000)  # 2 minutes in milliseconds
        print(f"DEBUG: Email timer active: {self.email_timer.isActive()}")
        print(f"DEBUG: Email timer interval: {self.email_timer.interval()}ms")
    
    def on_session_update(self, elapsed_minutes: float, progress_percent: float):
        """Hook called during session updates."""
        from datetime import datetime
        # Debug: Show email timer status every 30 seconds
        if int(elapsed_minutes * 60) % 30 == 0:  # Every 30 seconds
            timestamp = datetime.now().strftime("%H:%M:%S")
            print(f"DEBUG: [{timestamp}] Email timer status - Active: {self.email_timer.isActive()}, Session active: {self.session_active}, Has config: {bool(self.email_config)}")
            print(f"DEBUG: [{timestamp}] Email timer interval: {self.email_timer.interval()}ms, Processed emails: {len(self.processed_emails)}")
            
            # If timer is not active but session is active, restart it
            if self.session_active and self.email_config and not self.email_timer.isActive():
                print(f"DEBUG: [{timestamp}] Email timer stopped unexpectedly! Restarting...")
                self.email_timer.start(2 * 60 * 1000)  # 2 minutes
    
    def check_new_emails(self):
        """Check for new important emails during session"""
        from datetime import datetime
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"DEBUG: [{timestamp}] check_new_emails() called")
        
        if not self.session_active or not self.email_config:
            print(f"DEBUG: [{timestamp}] Email checking skipped - session_active: {self.session_active}, has_config: {bool(self.email_config)}")
            return
        
        try:
            print(f"DEBUG: [{timestamp}] Checking for new emails...")
            # Check for emails from the last 10 minutes to catch more emails
            recent_emails = self.get_recent_emails(hours=0.17)  # 10 minutes (10/60 = 0.17)
            print(f"DEBUG: [{timestamp}] Found {len(recent_emails)} recent emails")
            print(f"DEBUG: [{timestamp}] Currently have {len(self.processed_emails)} processed emails")
            
            new_emails_found = 0
            for email_data in recent_emails:
                # Create unique identifier for this email
                email_id = f"{email_data['from']}:{email_data['subject']}:{email_data.get('date', '')}"
                
                # Skip if we've already processed this email
                if email_id in self.processed_emails:
                    print(f"DEBUG: Skipping already processed email: {email_data['subject'][:50]}")
                    continue
                
                new_emails_found += 1
                print(f"DEBUG: Analyzing new email #{new_emails_found}: {email_data['subject'][:50]}")
                print(f"DEBUG: From: {email_data['from']}")
                task = self.analyze_email_importance(email_data)
                
                # Mark as processed regardless of outcome
                self.processed_emails.add(email_id)
                print(f"DEBUG: Added email to processed list. Total processed: {len(self.processed_emails)}")
                
                if task and task != "NO_ACTION":
                    print(f"DEBUG: Important email found - showing notification dialog")
                    print(f"DEBUG: Task: {task}")
                    
                    # Show email notification dialog
                    self.show_email_notification_dialog(task, email_data)
                    
                    # Also print to console for debugging
                    print(f"NOTIFICATION: Important Email - {task}")
                else:
                    print(f"DEBUG: Email not important or no action needed (task: {task})")
            
            print(f"DEBUG: Email check complete. Found {new_emails_found} new emails to analyze.")
        
        except Exception as e:
            print(f"Error checking new emails: {e}")
            import traceback
            traceback.print_exc()
            
            # Make sure the timer keeps running even if there's an error
            if self.session_active and self.email_config and not self.email_timer.isActive():
                print(f"DEBUG: Restarting email timer after error")
                self.email_timer.start(2 * 60 * 1000)
    
    def show_email_notification_dialog(self, task: str, email_data: Dict[str, Any]):
        """Show email notification dialog and potentially add to checklist"""
        try:
            # Create the notification dialog
            dialog = EmailNotificationDialog(task, email_data)
            
            # Store reference to prevent garbage collection
            self.current_email_dialog = dialog
            
            # Connect to handle the result when dialog is closed
            dialog.finished.connect(lambda result: self.handle_email_dialog_result(dialog, task))
            
            # Show non-blocking
            dialog.show()
            dialog.raise_()
            dialog.activateWindow()
            
            print(f"DEBUG: Email notification dialog shown for task: {task}")
            
        except Exception as e:
            print(f"Error showing email notification dialog: {e}")
            import traceback
            traceback.print_exc()
    
    def handle_email_dialog_result(self, dialog, task: str):
        """Handle the result of the email notification dialog"""
        try:
            if dialog.add_to_checklist and self._progress_popup:
                # Add the task to the current checklist
                print(f"DEBUG: Adding email task to checklist: {task}")
                
                # Get current goals and add the email task
                email_task = f"Email: {task}"
                
                # Add to the goals list and update the UI
                self._progress_popup.goals.append(email_task)
                
                # Create a new checkbox for the task
                from PyQt5.QtWidgets import QCheckBox
                checkbox = QCheckBox(email_task)
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
                    }
                    QCheckBox::indicator:checked {
                        background-color: #007aff;
                        border-color: #007aff;
                        image: url(data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIiIGhlaWdodD0iMTIiIHZpZXdCb3g9IjAgMCAxMiAxMiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEwIDNMNC41IDguNUwyIDYiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+Cjwvc3ZnPgo=);
                    }
                """)
                checkbox.stateChanged.connect(self._progress_popup.goal_checked)
                
                # Add to the goals scroll layout
                if hasattr(self._progress_popup, 'goal_checkboxes'):
                    # Find the goals scroll layout and add the checkbox
                    goals_widget = self._progress_popup.goals_container.findChild(QWidget)
                    if goals_widget:
                        goals_widget.layout().insertWidget(-1, checkbox)  # Insert before stretch
                        self._progress_popup.goal_checkboxes.append(checkbox)
                
                print(f"DEBUG: Email task added to checklist successfully")
                
            # Clean up the dialog reference
            self.current_email_dialog = None
            dialog.deleteLater()
            
        except Exception as e:
            print(f"Error handling email dialog result: {e}")
            import traceback
            traceback.print_exc()
            # Clean up reference even on error
            self.current_email_dialog = None
    
    def show_system_notification(self, title: str, message: str):
        """Show macOS system notification"""
        try:
            import subprocess
            script = f'''
            display notification "{message}" with title "{title}" sound name "default"
            '''
            subprocess.run(['osascript', '-e', script], check=True)
        except Exception as e:
            print(f"Error showing notification: {e}")
    
    def on_session_end(self, session_data: Dict[str, Any]):
        """Hook called when session ends"""
        print("DEBUG: Email plugin session_end hook called")
        print(f"DEBUG: Session was active: {self.session_active}")
        print(f"DEBUG: Email timer was active: {self.email_timer.isActive()}")
        
        self.session_active = False
        self.email_timer.stop()
        
        # Close any open email notification dialogs to ensure session summary takes priority
        if self.current_email_dialog:
            print("DEBUG: Closing email notification dialog for session end")
            try:
                self.current_email_dialog.close()
                self.current_email_dialog = None
            except Exception as e:
                print(f"DEBUG: Error closing email dialog: {e}")
        
        print("DEBUG: Email monitoring stopped")
        print(f"DEBUG: Total emails processed during session: {len(self.processed_emails)}")
    
    def cleanup(self):
        """Cleanup when plugin is disabled"""
        self.session_active = False
        if self.email_timer.isActive():
            self.email_timer.stop()