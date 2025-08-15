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
    password_dialog = PasswordDialog()
    password_dialog.add_save_option()  # Add checkbox to save password
    
    if password_dialog.exec_() == QDialog.Accepted:
        password = password_dialog.password
        
        # Verify password before saving
        if password and password_manager.verify_password(password):
            # Save password if user chose to
            if hasattr(password_dialog, 'save_password') and password_dialog.save_password:
                password_manager.save_password(password)
            return password
        else:
            print("Invalid password provided")
            return None
    
    return None


# Import here to avoid circular imports
from focus_launcher import PasswordDialog

# Enhance the existing PasswordDialog class
def add_save_option(self):
    """Add save password option to existing PasswordDialog"""
    if hasattr(self, '_save_option_added'):
        return
    
    self._save_option_added = True
    
    from PyQt5.QtWidgets import QCheckBox
    
    # Find the main layout
    layout = self.layout()
    
    # Add save password checkbox before buttons
    self.save_checkbox = QCheckBox("Remember password securely")
    self.save_checkbox.setChecked(True)  # Default to saving
    self.save_checkbox.setStyleSheet("""
        QCheckBox {
            font-size: 14px;
            color: #1d1d1f;
            margin: 10px 0;
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
    
    # Insert before the last item (which should be the button layout)
    layout.insertWidget(layout.count() - 1, self.save_checkbox)
    
    # Override accept to capture save preference
    original_accept = self.accept
    def accept_with_save():
        self.save_password = self.save_checkbox.isChecked()
        original_accept()
    
    self.accept = accept_with_save

# Monkey patch the method
PasswordDialog.add_save_option = add_save_option