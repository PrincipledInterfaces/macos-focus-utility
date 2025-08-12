#!/usr/bin/env python3
"""
Utility to manage saved sudo password for Focus Mode application.
"""

import sys
import argparse
from password_manager import SecurePasswordManager

def main():
    parser = argparse.ArgumentParser(
        description='Manage saved sudo password for Focus Mode',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  python manage_password.py --status         # Check if password is saved
  python manage_password.py --clear          # Remove saved password
  python manage_password.py --verify         # Test if saved password works
        '''
    )
    
    parser.add_argument('--status', action='store_true',
                       help='Check if password is saved')
    parser.add_argument('--clear', action='store_true',
                       help='Remove saved password')
    parser.add_argument('--verify', action='store_true',
                       help='Verify saved password works')
    
    args = parser.parse_args()
    
    if not any([args.status, args.clear, args.verify]):
        parser.print_help()
        return
    
    pm = SecurePasswordManager()
    
    if args.status:
        if pm.has_saved_password():
            print("✓ Password is saved and encrypted")
        else:
            print("✗ No password is saved")
    
    if args.verify:
        if pm.has_saved_password():
            password = pm.get_password()
            if password and pm.verify_password(password):
                print("✓ Saved password is valid")
            else:
                print("✗ Saved password is invalid or corrupted")
        else:
            print("✗ No password is saved to verify")
    
    if args.clear:
        if pm.clear_password():
            print("✓ Saved password has been removed")
        else:
            print("✗ Failed to remove saved password")

if __name__ == '__main__':
    main()