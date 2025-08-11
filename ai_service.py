#!/usr/bin/env python3

"""
AI Service for Focus Utility
Handles AI-powered app categorization and custom mode generation
"""

import os
import json
import subprocess
import re
from typing import List, Dict, Tuple
from groq import Groq

class AIService:
    def __init__(self):
        self.client = None
        self._load_api_key()
    
    def _load_api_key(self):
        """Load Groq API key from file"""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            key_file = os.path.join(script_dir, 'groq_api_key.txt')
            
            if os.path.exists(key_file):
                with open(key_file, 'r') as f:
                    api_key = f.read().strip()
                if api_key:
                    self.client = Groq(api_key=api_key)
                    print("AI Service initialized with Groq API")
                else:
                    print("Empty API key file")
            else:
                print("Groq API key file not found at groq_api_key.txt")
        except Exception as e:
            print(f"Error loading API key: {e}")
    
    def is_available(self) -> bool:
        """Check if AI service is available"""
        return self.client is not None
    
    def get_installed_applications(self) -> List[str]:
        """Get list of all installed applications on macOS"""
        apps = []
        
        # Get applications from /Applications
        try:
            for item in os.listdir('/Applications'):
                if item.endswith('.app'):
                    app_name = item.replace('.app', '')
                    apps.append(app_name)
        except:
            pass
        
        # Get applications from ~/Applications
        try:
            home_apps = os.path.expanduser('~/Applications')
            if os.path.exists(home_apps):
                for item in os.listdir(home_apps):
                    if item.endswith('.app'):
                        app_name = item.replace('.app', '')
                        apps.append(app_name)
        except:
            pass
        
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
            'WindowServer', 'Dock', 'SystemUIServer', 'loginwindow'
        }
        
        # Remove system apps and return unique apps
        user_apps = [app for app in set(apps) if app not in system_apps]
        return sorted(user_apps)
    
    def categorize_apps_for_modes(self, apps: List[str]) -> Dict[str, List[str]]:
        """Use AI to categorize apps for different focus modes"""
        if not self.is_available():
            print("AI service not available")
            return {}
        
        try:
            apps_text = '\n'.join(apps)
            
            prompt = f"""You are helping create focus mode configurations for a productivity app. 
            
Given this list of applications installed on a user's Mac:

{apps_text}

Please categorize each app for the following focus modes:
1. PRODUCTIVITY - Apps that help with work, productivity, coding, writing, business tasks
2. CREATIVITY - Apps for creative work like design, music, video editing, art, writing
3. SOCIAL_MEDIA_DETOX - Apps that are allowed during social media detox (productivity tools, utilities, creative apps, but NOT social media, games, entertainment)

For each app, determine which modes it should be ALLOWED in. Many apps may be allowed in multiple modes.

Return your response as a JSON object with this exact structure:
{{
    "productivity": ["App1", "App2", ...],
    "creativity": ["App1", "App3", ...],
    "social": ["App1", "App2", ...]
}}

Be thoughtful about categorization:
- Productivity: Development tools, office apps, note-taking, project management, utilities
- Creativity: Design software, media editing, music production, writing tools
- Social media detox: Everything except social media apps, games, entertainment streaming

Only include apps that clearly belong in each category. When in doubt, be conservative."""

            response = self.client.chat.completions.create(
                messages=[
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                model="llama-3.1-8b-instant",
                max_tokens=2000,
                temperature=0.1
            )
            
            content = response.choices[0].message.content.strip()
            
            # Extract JSON from response (handle markdown code blocks)
            json_match = re.search(r'```json\s*(\{.*?\})\s*```', content, re.DOTALL)
            if not json_match:
                json_match = re.search(r'\{.*\}', content, re.DOTALL)
            
            if json_match:
                json_str = json_match.group(1) if json_match.lastindex else json_match.group()
                result = json.loads(json_str)
                print(f"Categorized {len(apps)} apps for focus modes")
                return result
            else:
                print("Could not parse AI response")
                return {}
                
        except Exception as e:
            print(f"Error categorizing apps: {e}")
            return {}
    
    def generate_website_blocks_for_modes(self) -> Dict[str, List[str]]:
        """Generate comprehensive website blocks for each focus mode"""
        if not self.is_available():
            print("AI service not available")
            return {}
        
        try:
            prompt = """Create website blocking lists for focus modes. Return ONLY valid JSON with these domains to block:

{
    "productivity": ["facebook.com", "twitter.com", "instagram.com", "tiktok.com", "reddit.com", "youtube.com", "netflix.com", "twitch.tv", "discord.com"],
    "creativity": ["facebook.com", "twitter.com", "instagram.com", "tiktok.com", "reddit.com", "twitch.tv", "discord.com"],
    "social": ["facebook.com", "twitter.com", "instagram.com", "tiktok.com", "reddit.com", "youtube.com", "netflix.com", "twitch.tv", "discord.com", "steam.com", "amazon.com"]
}

Add more relevant blocking domains for each mode. Keep response under 1500 tokens."""

            response = self.client.chat.completions.create(
                messages=[
                    {
                        "role": "user", 
                        "content": prompt
                    }
                ],
                model="llama-3.1-8b-instant",
                max_tokens=2000,
                temperature=0.1
            )
            
            content = response.choices[0].message.content.strip()
            
            # Extract JSON from response (handle markdown code blocks)
            json_match = re.search(r'```json\s*(\{.*?\})\s*```', content, re.DOTALL)
            if not json_match:
                json_match = re.search(r'\{.*\}', content, re.DOTALL)
            
            if json_match:
                json_str = json_match.group(1) if json_match.lastindex else json_match.group()
                result = json.loads(json_str)
                print(f"Generated website blocks for focus modes")
                return result
            else:
                print("Could not parse AI response for website blocks")
                return {}
                
        except Exception as e:
            print(f"Error generating website blocks: {e}")
            return {}
    
    def create_custom_mode(self, mode_name: str, description: str) -> bool:
        """Create a custom focus mode using AI"""
        if not self.is_available():
            print("AI service not available")
            return False
        
        try:
            # Get system apps for context
            system_apps = self.get_installed_applications()
            apps_context = '\n'.join(system_apps)  # Use all installed apps
            
            prompt = f"""Create a custom focus mode configuration based on the user's description.

Mode Name: {mode_name}
Description: {description}

Available apps on system:
{apps_context}

Based on the mode description, create:
1. A list of apps that should be ALLOWED during this focus mode (choose from the available apps list)
2. A list of specific website domains that should be BLOCKED during this focus mode

IMPORTANT: Return ONLY valid JSON with NO comments or explanations. Use specific domain names only.

Example format:
{{
    "apps": ["Google Chrome", "VS Code", "Terminal"],
    "blocked_sites": ["facebook.com", "twitter.com", "reddit.com"]
}}"""

            response = self.client.chat.completions.create(
                messages=[
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                model="llama-3.1-8b-instant", 
                max_tokens=1500,
                temperature=0.2
            )
            
            content = response.choices[0].message.content.strip()
            print(f"DEBUG: AI response for custom mode: {content}")
            
            # Extract JSON from response (handle markdown code blocks)
            json_match = re.search(r'```json\s*(\{.*?\})\s*```', content, re.DOTALL)
            if not json_match:
                json_match = re.search(r'\{.*\}', content, re.DOTALL)
            
            if json_match:
                json_str = json_match.group(1) if json_match.lastindex else json_match.group()
                print(f"DEBUG: Extracted JSON: {json_str}")
                result = json.loads(json_str)
                
                # Save the custom mode files
                self._save_custom_mode(mode_name, result.get('apps', []), result.get('blocked_sites', []))
                print(f"Created custom mode: {mode_name}")
                return True
            else:
                print("Could not parse AI response for custom mode")
                return False
                
        except Exception as e:
            print(f"Error creating custom mode: {e}")
            return False
    
    def _save_custom_mode(self, mode_name: str, apps: List[str], blocked_sites: List[str]):
        """Save custom mode to files"""
        script_dir = os.path.dirname(os.path.abspath(__file__))
        
        # Clean mode name for filename
        clean_name = re.sub(r'[^\w\s-]', '', mode_name).strip()
        clean_name = re.sub(r'[-\s]+', '_', clean_name).lower()
        
        # Save apps file
        modes_dir = os.path.join(script_dir, 'modes', 'custom')
        os.makedirs(modes_dir, exist_ok=True)
        
        apps_file = os.path.join(modes_dir, f'{clean_name}.txt')
        with open(apps_file, 'w') as f:
            f.write('\n'.join(apps))
        
        # Save hosts file with comprehensive blocking
        hosts_dir = os.path.join(script_dir, 'hosts', 'custom')  
        os.makedirs(hosts_dir, exist_ok=True)
        
        hosts_file = os.path.join(hosts_dir, f'{clean_name}_hosts')
        with open(hosts_file, 'w') as f:
            for site in blocked_sites:
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

# Global instance
ai_service = AIService()