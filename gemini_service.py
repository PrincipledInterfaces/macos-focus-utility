#!/usr/bin/env python3

"""
Gemini AI Service for Focus Utility
Handles AI-powered chat with better instruction following
"""

import os
import json
import requests
import time
from typing import List, Dict, Optional

class GeminiService:
    def __init__(self):
        self.api_key = None
        self.base_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        self._load_api_key()
    
    def _load_api_key(self):
        """Load Gemini API key from file"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            key_file = os.path.join(script_dir, 'gemini_api_key.txt')
            
            if os.path.exists(key_file):
                with open(key_file, 'r') as f:
                    api_key = f.read().strip()
                if api_key:
                    self.api_key = api_key
                    print("Gemini AI Service initialized")
                else:
                    print("Empty Gemini API key file")
            else:
                print("Gemini API key file not found at gemini_api_key.txt")
        except Exception as e:
            print(f"Error loading Gemini API key: {e}")
    
    def is_available(self) -> bool:
        """Check if Gemini service is available"""
        return self.api_key is not None
    
    def ask(self, prompt: str, system_prompt: str = None, conversation_history: list = None, max_tokens: int = 1024) -> str:
        """
        General-purpose AI function using Gemini.
        
        Args:
            prompt: The prompt to send to the AI
            system_prompt: Optional system prompt to set AI behavior
            conversation_history: Optional list of previous messages for context
            max_tokens: Maximum tokens in response (default: 1024)
            
        Returns:
            The AI's response as a string, or empty string if error
        """
        if not self.is_available():
            print("Gemini service not available")
            return ""
        
        try:
            # Build the conversation
            contents = []
            
            # Add system prompt as first user message if provided
            if system_prompt:
                contents.append({
                    "role": "user",
                    "parts": [{"text": f"SYSTEM INSTRUCTIONS: {system_prompt}\n\nPlease acknowledge these instructions."}]
                })
                contents.append({
                    "role": "model",
                    "parts": [{"text": "I understand and will follow these system instructions."}]
                })
            
            # Add conversation history if provided
            if conversation_history:
                for msg in conversation_history:
                    role = "model" if msg["role"] == "assistant" else "user"
                    contents.append({
                        "role": role,
                        "parts": [{"text": msg["content"]}]
                    })
            
            # Add current user message
            contents.append({
                "role": "user", 
                "parts": [{"text": prompt}]
            })
            
            # Prepare request
            payload = {
                "contents": contents,
                "generationConfig": {
                    "maxOutputTokens": max_tokens,
                    "temperature": 0.7,
                    "topK": 40,
                    "topP": 0.95,
                }
            }
            
            headers = {
                "Content-Type": "application/json"
            }
            
            # Make API request with retry logic for 503 errors
            url = f"{self.base_url}?key={self.api_key}"
            
            for attempt in range(3):  # Try up to 3 times
                try:
                    response = requests.post(url, headers=headers, json=payload, timeout=30)
                    
                    if response.status_code == 200:
                        data = response.json()
                        if 'candidates' in data and len(data['candidates']) > 0:
                            candidate = data['candidates'][0]
                            if 'content' in candidate and 'parts' in candidate['content']:
                                return candidate['content']['parts'][0]['text'].strip()
                            else:
                                print("Unexpected Gemini response format")
                                return ""
                        else:
                            print("No candidates in Gemini response")
                            return ""
                    elif response.status_code == 503:
                        # Model overloaded - wait and retry
                        wait_time = (attempt + 1) * 2  # 2, 4, 6 seconds
                        print(f"Gemini overloaded, retrying in {wait_time}s... (attempt {attempt + 1}/3)")
                        time.sleep(wait_time)
                        continue
                    else:
                        print(f"Gemini API error: {response.status_code} - {response.text}")
                        return ""
                        
                except requests.exceptions.Timeout:
                    print(f"Gemini request timeout (attempt {attempt + 1}/3)")
                    if attempt < 2:  # Don't sleep on last attempt
                        time.sleep(2)
                    continue
            
            # If we get here, all retries failed
            print("Gemini service unavailable after 3 attempts. You may want to try again later.")
            return ""
                
        except Exception as e:
            print(f"Error calling Gemini service: {e}")
            return ""
    
    def get_installed_applications(self) -> List[str]:
        """Get list of all installed applications on macOS"""
        apps = []
        
        def scan_directory(directory):
            """Scan directory for .app bundles, including subdirectories"""
            try:
                for item in os.listdir(directory):
                    item_path = os.path.join(directory, item)
                    if item.endswith('.app'):
                        app_name = item.replace('.app', '')
                        apps.append(app_name)
                    elif os.path.isdir(item_path) and not item.startswith('.'):
                        # Check subdirectories for .app bundles (one level deep)
                        try:
                            for subitem in os.listdir(item_path):
                                if subitem.endswith('.app'):
                                    app_name = subitem.replace('.app', '')
                                    apps.append(app_name)
                        except:
                            pass
            except:
                pass
        
        # Get applications from /Applications
        scan_directory('/Applications')
        
        # Get applications from ~/Applications
        home_apps = os.path.expanduser('~/Applications')
        if os.path.exists(home_apps):
            scan_directory(home_apps)
        
        # Filter out system apps and duplicates
        system_apps = {
            'Activity Monitor', 'AirPort Utility', 'Automator', 'Bluetooth Screen Sharing',
            'Boot Camp Assistant', 'Calculator', 'Calendar', 'Chess', 'ColorSync Utility',
            'Console', 'Contacts', 'Digital Color Meter', 'Directory Utility', 'Disk Utility',
            'DVD Player', 'FaceTime', 'Font Book', 'Grapher', 'Image Capture', 'Keychain Access',
            'Launchpad', 'Mail', 'Maps', 'Messages', 'Migration Assistant', 'Notes', 'Photo Booth',
            'Photos', 'Preview', 'QuickTime Player', 'Reminders', 'Safari', 'Screenshot Path',
            'Stickies', 'System Information', 'System Preferences', 'Terminal', 'TextEdit',
            'Time Machine', 'VoiceOver Utility', 'Archive Utility', 'Finder', 'System Events',
            'WindowServer', 'Dock', 'SystemUIServer', 'loginwindow', 'Uninstall Resolve',
            'Adobe Activation Tool'
        }
        
        # Remove system apps and return unique apps
        user_apps = [app for app in set(apps) if app not in system_apps]
        return sorted(user_apps)


# Convenience function for easy importing
def ask_gemini(prompt: str, system_prompt: str = None, conversation_history: list = None, max_tokens: int = 1024) -> str:
    """
    Convenience function for Gemini AI queries.
    
    Args:
        prompt: The prompt to send to the AI
        system_prompt: Optional system prompt to set AI behavior
        conversation_history: Optional list of previous messages for context
        max_tokens: Maximum tokens in response (default: 1024)
        
    Returns:
        The AI's response as a string, or empty string if error
    
    Example:
        from gemini_service import ask_gemini
        response = ask_gemini("What's the weather like?", system_prompt="Be concise")
    """
    service = GeminiService()
    return service.ask(prompt, system_prompt, conversation_history, max_tokens)

# Global instance
gemini_service = GeminiService()