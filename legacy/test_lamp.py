#!/usr/bin/env python3

import requests
import json

# Test the lamp directly with explicit green color
lamp_ip = "192.168.1.14"  # Your lamp IP

def test_green():
    """Test lamp with explicit green values"""
    print("Testing lamp with explicit green RGB(129, 202, 95)...")
    
    data = {
        "command": "set_mode",
        "mode": "test_green",
        "primaryColor": [129, 202, 95],  # Exact green from settings
        "whiteTemp": 4000,
        "movement": 15,
        "frontWhite": False
    }
    
    try:
        response = requests.post(f"http://{lamp_ip}/control", json=data, timeout=5)
        print(f"Response status: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            print("✅ Command sent successfully - check if lamp shows green")
        else:
            print("❌ Command failed")
            
    except Exception as e:
        print(f"❌ Error: {e}")

def test_pure_green():
    """Test with pure green RGB(0, 255, 0)"""
    print("\nTesting lamp with pure green RGB(0, 255, 0)...")
    
    data = {
        "command": "set_mode", 
        "mode": "test_pure_green",
        "primaryColor": [0, 255, 0],  # Pure green
        "whiteTemp": 4000,
        "movement": 0,  # No movement for solid color
        "frontWhite": False
    }
    
    try:
        response = requests.post(f"http://{lamp_ip}/control", json=data, timeout=5)
        print(f"Response status: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            print("✅ Command sent successfully - check if lamp shows pure green")
        else:
            print("❌ Command failed")
            
    except Exception as e:
        print(f"❌ Error: {e}")

def test_red():
    """Test with red to see if colors are swapped"""
    print("\nTesting lamp with red RGB(255, 0, 0)...")
    
    data = {
        "command": "set_mode",
        "mode": "test_red", 
        "primaryColor": [255, 0, 0],  # Pure red
        "whiteTemp": 4000,
        "movement": 0,
        "frontWhite": False
    }
    
    try:
        response = requests.post(f"http://{lamp_ip}/control", json=data, timeout=5)
        print(f"Response status: {response.status_code}")
        if response.status_code == 200:
            print("✅ Red test sent - check if lamp shows red")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    print("🔧 Lamp Color Debugging Tool")
    print("=" * 40)
    
    test_green()
    input("\nPress Enter to test pure green...")
    test_pure_green()
    input("\nPress Enter to test red...")
    test_red()
    
    print("\n" + "=" * 40)
    print("Compare the colors:")
    print("- First test should match creativity mode")
    print("- Second test should be bright pure green")
    print("- Third test should be pure red")
    print("If red shows as green, your LED strip has swapped channels")