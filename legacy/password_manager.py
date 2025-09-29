#!/usr/bin/env python3
"""
Secure Password Manager for Focus Mode Application
Handles encrypted storage and retrieval of sudo passwords.
"""

import os
import json
import hashlib
import base64
from typing import Optional
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

class SecurePasswordManager:
    """
    Manages encrypted storage of sudo password with machine-specific encryption.
    """
    
    def __init__(self, app_dir: str = None):
        self.app_dir = app_dir or os.path.dirname(os.path.abspath(__file__))
        self.password_file = os.path.join(self.app_dir, '.focus_auth.enc')
        self.machine_key = self._get_machine_key()
        
    def _get_machine_key(self) -> bytes:
        """
        Generate a machine-specific key for encryption.
        Uses machine-specific identifiers to create a unique key.
        """
        try:
            import platform
            import getpass
            
            # Combine multiple machine-specific identifiers
            machine_data = f"{platform.node()}{platform.machine()}{getpass.getuser()}"
                
            # Create a stable key from machine data
            key_material = hashlib.sha256(machine_data.encode()).digest()
            
            # Use PBKDF2 to derive encryption key
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=b'focus_mode_salt',  # Fixed salt for consistency
                iterations=100000,
            )
            key = base64.urlsafe_b64encode(kdf.derive(key_material))
            return key
            
        except Exception as e:
            print(f"Warning: Could not generate machine key: {e}")
            # Fallback to a basic key
            return base64.urlsafe_b64encode(b'fallback_key_focus_mode_app_32b')
    
    def save_password(self, password: str) -> bool:
        """
        Save password in encrypted form.
        
        Args:
            password: The sudo password to save
            
        Returns:
            True if saved successfully, False otherwise
        """
        try:
            # Encrypt the password
            fernet = Fernet(self.machine_key)
            encrypted_password = fernet.encrypt(password.encode())
            
            # Create metadata
            data = {
                'encrypted_password': base64.urlsafe_b64encode(encrypted_password).decode(),
                'version': 1,
                'app': 'focus_mode'
            }
            
            # Save to file with restricted permissions
            with open(self.password_file, 'w') as f:
                json.dump(data, f)
            
            # Set restrictive file permissions (600 - owner read/write only)
            os.chmod(self.password_file, 0o600)
            
            print("Password saved securely")
            return True
            
        except Exception as e:
            print(f"Error saving password: {e}")
            return False
    
    def get_password(self) -> Optional[str]:
        """
        Retrieve and decrypt the saved password.
        
        Returns:
            The decrypted password if available, None otherwise
        """
        try:
            if not os.path.exists(self.password_file):
                return None
            
            # Read encrypted data
            with open(self.password_file, 'r') as f:
                data = json.load(f)
            
            # Verify format
            if 'encrypted_password' not in data:
                return None
            
            # Decrypt password
            fernet = Fernet(self.machine_key)
            encrypted_password = base64.urlsafe_b64decode(data['encrypted_password'])
            decrypted_password = fernet.decrypt(encrypted_password)
            
            return decrypted_password.decode()
            
        except Exception as e:
            print(f"Error retrieving password: {e}")
            return None
    
    def has_saved_password(self) -> bool:
        """
        Check if a password is saved.
        
        Returns:
            True if password exists and can be decrypted, False otherwise
        """
        return self.get_password() is not None
    
    def clear_password(self) -> bool:
        """
        Remove the saved password file.
        
        Returns:
            True if cleared successfully, False otherwise
        """
        try:
            if os.path.exists(self.password_file):
                os.remove(self.password_file)
                print("Saved password cleared")
            return True
        except Exception as e:
            print(f"Error clearing password: {e}")
            return False
    
    def verify_password(self, password: str) -> bool:
        """
        Verify a password by testing it with a simple sudo command.
        
        Args:
            password: The password to verify
            
        Returns:
            True if password is correct, False otherwise
        """
        try:
            import subprocess
            
            # Test password with a harmless sudo command
            cmd = f'echo "{password}" | sudo -S -k whoami 2>/dev/null'
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
            
            return result.returncode == 0 and 'root' in result.stdout
            
        except Exception as e:
            print(f"Error verifying password: {e}")
            return False


def get_sudo_password(force_new: bool = False) -> Optional[str]:
    """
    Get sudo password, using stored password if available.
    
    Args:
        force_new: If True, always prompt for new password
        
    Returns:
        The sudo password if obtained, None if cancelled
    """
    password_manager = SecurePasswordManager()
    
    # Try to use stored password first (unless forcing new)
    if not force_new and password_manager.has_saved_password():
        stored_password = password_manager.get_password()
        if stored_password:
            # Verify the stored password still works
            if password_manager.verify_password(stored_password):
                print("Using stored password")
                return stored_password
            else:
                print("Stored password no longer valid, prompting for new one")
                password_manager.clear_password()
    
    # Need to prompt for password
    from PyQt5.QtWidgets import QDialog
    password_dialog = create_password_dialog()
    
    if password_dialog and password_dialog.exec_() == QDialog.Accepted:
        password = password_dialog.password
        
        # Verify password before saving
        if password and password_manager.verify_password(password):
            # Save password if user chose to
            if password_dialog.save_password:
                if password_manager.save_password(password):
                    print("Password saved successfully")
                else:
                    print("Failed to save password")
            return password
        else:
            print("Invalid password provided")
            return None
    
    return None


# Create a simple password dialog function without circular imports
def create_password_dialog():
    """Create a password dialog with save option"""
    try:
        from PyQt5.QtWidgets import QDialog, QVBoxLayout, QLabel, QLineEdit, QPushButton, QHBoxLayout, QCheckBox
        from PyQt5.QtCore import Qt
        from PyQt5.QtGui import QFont
        
        class PasswordDialog(QDialog):
            def __init__(self):
                super().__init__()
                self.password = None
                self.save_password = True
                self.init_ui()
            
            def init_ui(self):
                self.setWindowTitle('Authentication Required')
                self.setFixedSize(400, 200)
                self.setWindowFlags(Qt.WindowStaysOnTopHint)
                
                layout = QVBoxLayout()
                layout.setContentsMargins(30, 30, 30, 30)
                layout.setSpacing(15)
                
                # Title
                title = QLabel("Enter your password:")
                title.setStyleSheet("""
                    font-size: 16px;
                    font-weight: 600;
                    color: #1d1d1f;
                """)
                layout.addWidget(title)
                
                # Password input
                self.password_input = QLineEdit()
                self.password_input.setEchoMode(QLineEdit.Password)
                self.password_input.setStyleSheet("""
                    QLineEdit {
                        padding: 8px 12px;
                        font-size: 14px;
                        border: 1px solid #d1d1d6;
                        border-radius: 6px;
                        background-color: white;
                    }
                """)
                layout.addWidget(self.password_input)
                
                # Save checkbox
                self.save_checkbox = QCheckBox("Remember password securely")
                self.save_checkbox.setChecked(True)
                self.save_checkbox.setStyleSheet("""
                    QCheckBox {
                        font-size: 14px;
                        color: #1d1d1f;
                    }
                    QCheckBox::indicator {
                        width: 18px;
                        height: 18px;
                    }
                    QCheckBox::indicator:unchecked {
                        border: 2px solid #d1d1d6;
                        border-radius: 3px;
                        background-color: white;
                    }
                    QCheckBox::indicator:checked {
                        border: 2px solid #007aff;
                        border-radius: 3px;
                        background-color: #007aff;
                    }
                """)
                layout.addWidget(self.save_checkbox)
                
                # Buttons
                button_layout = QHBoxLayout()
                
                cancel_btn = QPushButton("Cancel")
                cancel_btn.clicked.connect(self.reject)
                ok_btn = QPushButton("OK")
                ok_btn.clicked.connect(self.accept_password)
                ok_btn.setDefault(True)
                
                button_layout.addWidget(cancel_btn)
                button_layout.addWidget(ok_btn)
                layout.addLayout(button_layout)
                
                self.setLayout(layout)
                self.password_input.setFocus()
            
            def accept_password(self):
                self.password = self.password_input.text()
                self.save_password = self.save_checkbox.isChecked()
                self.accept()
        
        return PasswordDialog()
    except Exception as e:
        print(f"Error creating password dialog: {e}")
        return None