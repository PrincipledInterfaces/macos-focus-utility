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
                                # DEBUG: print(f"Candidate data: {candidate}")
                                # Check if it's a MAX_TOKENS issue
                                if candidate.get('finishReason') == 'MAX_TOKENS':
                                    print("Response was truncated due to token limit")
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
    
    def categorize_apps_for_modes(self, apps: List[str]) -> Dict[str, List[str]]:
        """Categorize applications for focus modes using Gemini AI with batching"""
        if not self.is_available():
            print("Gemini AI service not available")
            return {}
        
        # Process apps in smaller batches to avoid prompt length limits
        batch_size = 5  # Process 5 apps at a time to avoid token limits
        all_results = {'productivity': [], 'creativity': [], 'social_media_detox': []}
        
        try:
            import re
            import json
            
            # Process apps in batches
            for i in range(0, len(apps), batch_size):
                batch_apps = apps[i:i + batch_size]
                apps_text = '\n'.join(batch_apps)
                
                prompt = f"""Return JSON with these exact keys:
{{"productivity": [], "creativity": [], "social_media_detox": []}}

Categorize these apps into focus modes. Apps can appear in MULTIPLE categories:
{apps_text}

IMPORTANT: Many apps should appear in multiple categories.

PRODUCTIVITY mode (work, business, coding):
- Browsers (Chrome, Safari, Firefox, Edge) - essential for research, documentation
- Code editors, IDEs, terminals
- Office apps (Word, Excel, PowerPoint, Pages, Numbers)
- Communication tools for work (Slack, Teams, Zoom, email clients)
- File managers, utilities, system tools
- Note-taking apps (Notion, Obsidian, Bear)
- Project management tools
- PDF readers, text editors

CREATIVITY mode (creative work, design, content creation):
- Browsers (Chrome, Safari, Firefox) - for inspiration, tutorials, uploading work
- Design tools (Photoshop, Illustrator, Figma, Sketch)
- Video/audio editing (Final Cut, Premiere, Logic, Audacity)
- 3D modeling, animation tools
- Writing apps, text editors for creative writing
- Music production software
- Photography apps
- Drawing/illustration apps
- Music streaming apps (Spotify, Apple Music) - for background music while creating
- General text editors - useful for writing, scripting
- File managers - organizing creative assets

SOCIAL_MEDIA_DETOX mode (allow everything EXCEPT dedicated social media platforms):
- Browsers (Chrome, Safari, Firefox) - for work/learning/general use
- ALL productivity apps (office, coding, utilities)
- ALL creativity apps (design, art, music production)
- ALL games and entertainment apps (Steam games, puzzle games, media players)
- ALL streaming services (Netflix, Spotify, YouTube for entertainment)
- System utilities, file managers, educational apps
- Communication tools for work (email, Slack, Teams, Zoom)
- ONLY EXCLUDE: Dedicated social media platforms that are primarily for social networking:
  * Facebook, Instagram, Twitter/X, TikTok, Snapchat
  * LinkedIn (professional social network)  
  * Discord (social chat platform)
  * WhatsApp, Telegram (social messaging)
  * Reddit (social discussion platform)

Think about real-world usage:
- Someone doing creative work needs browsers for tutorials, references, uploading work
- Creative people use music apps for background ambience while working
- Text editors can be used for creative writing, not just coding
- General-purpose apps often serve multiple functions
- Consider indirect creative uses: Excel for planning projects, Notion for mood boards

Apps that are NOT entertainment/distraction but could support creativity:
- Music/audio apps (background music aids creativity)
- Organization tools (project planning)
- General productivity apps (research, documentation)

Return only JSON."""

                response = self.ask(prompt, max_tokens=2000)
                print(f"Batch {i//batch_size + 1}: response length {len(response)}")
                
                if not response:
                    print(f"Empty response for batch {i//batch_size + 1}")
                    continue
                
                # Check if response was truncated
                if len(response) >= 1950:  # Close to max_tokens limit
                    print(f"Response was truncated for batch {i//batch_size + 1}")
                    # Try with smaller batch size recursively
                    if len(batch_apps) > 1:
                        print(f"Retrying batch {i//batch_size + 1} with smaller batches...")
                        for j in range(0, len(batch_apps), 2):  # Split into groups of 2
                            mini_batch = batch_apps[j:j+2]
                            mini_apps_text = '\n'.join(mini_batch)
                            mini_prompt = f"""Return JSON with these exact keys:
{{"productivity": [], "creativity": [], "social_media_detox": []}}

Categorize these apps:
{mini_apps_text}

Rules:
- productivity: work tools, coding, office, utilities
- creativity: design, media editing, art, music
- social_media_detox: ALL apps except social media/games/entertainment

Return only JSON."""
                            mini_response = self.ask(mini_prompt, max_tokens=1000)
                            if mini_response and len(mini_response) < 950:
                                # Process mini response using same logic below
                                mini_json_str = None
                                mini_json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', mini_response, re.DOTALL)
                                if mini_json_match:
                                    mini_json_str = mini_json_match.group(1)
                                else:
                                    start_idx = mini_response.find('{')
                                    if start_idx != -1:
                                        brace_count = 0
                                        end_idx = start_idx
                                        for k, char in enumerate(mini_response[start_idx:], start_idx):
                                            if char == '{':
                                                brace_count += 1
                                            elif char == '}':
                                                brace_count -= 1
                                                if brace_count == 0:
                                                    end_idx = k
                                                    break
                                        if brace_count == 0:
                                            mini_json_str = mini_response[start_idx:end_idx + 1]
                                
                                if mini_json_str:
                                    try:
                                        mini_result = json.loads(mini_json_str)
                                        if isinstance(mini_result, dict):
                                            for mode in ['productivity', 'creativity', 'social_media_detox']:
                                                apps_for_mode = mini_result.get(mode, [])
                                                if isinstance(apps_for_mode, list):
                                                    all_results[mode].extend(apps_for_mode)
                                            print(f"Successfully processed mini-batch ({len(mini_batch)} apps)")
                                    except:
                                        pass
                        continue  # Skip normal processing for truncated response
                
                # Extract and clean JSON from response
                json_str = None
                
                # Try to find JSON in code blocks first
                json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', response, re.DOTALL)
                if json_match:
                    json_str = json_match.group(1)
                else:
                    # Look for bare JSON structure
                    start_idx = response.find('{')
                    if start_idx != -1:
                        brace_count = 0
                        end_idx = start_idx
                        for j, char in enumerate(response[start_idx:], start_idx):
                            if char == '{':
                                brace_count += 1
                            elif char == '}':
                                brace_count -= 1
                                if brace_count == 0:
                                    end_idx = j
                                    break
                        if brace_count == 0:
                            json_str = response[start_idx:end_idx + 1]
                
                if json_str:
                    # Clean up JSON
                    json_str = re.sub(r'"\s+[^",\]\}]+\s*([,\]\}])', r'"\1', json_str)
                    json_str = re.sub(r',\s*([}\]])', r'\1', json_str)
                    
                    try:
                        batch_result = json.loads(json_str)
                        
                        # Validate and merge results
                        if isinstance(batch_result, dict):
                            # Handle different possible key formats
                            for mode in ['productivity', 'creativity', 'social_media_detox']:
                                apps_for_mode = batch_result.get(mode, [])
                                if isinstance(apps_for_mode, list):
                                    all_results[mode].extend(apps_for_mode)
                            print(f"Successfully processed batch {i//batch_size + 1} ({len(batch_apps)} apps)")
                        else:
                            print(f"Invalid JSON structure in batch {i//batch_size + 1}")
                            
                    except json.JSONDecodeError as e:
                        print(f"JSON decode error in batch {i//batch_size + 1}: {e}")
                        continue
                else:
                    print(f"No JSON found in batch {i//batch_size + 1} response")
                    continue
            
            # Remove duplicates while preserving order
            for mode in all_results:
                all_results[mode] = list(dict.fromkeys(all_results[mode]))
            
            total_categorized = sum(len(apps) for apps in all_results.values())
            print(f"Categorized {len(apps)} apps into {total_categorized} total assignments using Gemini")
            return all_results
                
        except Exception as e:
            print(f"Error categorizing apps with Gemini: {e}")
            return {}
    
    def generate_website_blocks_for_modes(self) -> Dict[str, List[str]]:
        """Generate comprehensive website blocks for each focus mode using Gemini AI"""
        if not self.is_available():
            print("Gemini AI service not available")
            return {}
        
        try:
            import re
            import json
            
            prompt = """IMPORTANT: Respond with ONLY valid JSON. No explanations, no extra text.

Return website blocking lists for focus modes:

{
    "productivity": ["facebook.com", "twitter.com", "instagram.com", "tiktok.com", "reddit.com", "youtube.com", "discord.com", "snapchat.com"],
    "creativity": ["facebook.com", "twitter.com", "instagram.com", "tiktok.com", "reddit.com", "discord.com", "snapchat.com"],
    "social_media_detox": ["facebook.com", "twitter.com", "instagram.com", "tiktok.com", "reddit.com", "discord.com", "snapchat.com", "linkedin.com", "whatsapp.com", "telegram.org"]
}

CRITICAL: Return ONLY valid JSON. No text before or after."""

            response = self.ask(prompt, max_tokens=2000)
            
            # Extract and clean JSON from response (same robust method as apps)
            # DEBUG: print(f"Raw website response length: {len(response)}")
            
            # Find the first valid JSON structure, ignoring any garbage before/after
            json_str = None
            
            # Try to find JSON in code blocks first
            json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', response, re.DOTALL)
            if json_match:
                json_str = json_match.group(1)
            else:
                # Look for bare JSON structure - find the outermost braces
                start_idx = response.find('{')
                if start_idx != -1:
                    brace_count = 0
                    end_idx = start_idx
                    for i, char in enumerate(response[start_idx:], start_idx):
                        if char == '{':
                            brace_count += 1
                        elif char == '}':
                            brace_count -= 1
                            if brace_count == 0:
                                end_idx = i
                                break
                    if brace_count == 0:
                        json_str = response[start_idx:end_idx + 1]
            
            if json_str:
                # Aggressive cleaning of corrupted JSON
                json_str = re.sub(r'"\s+[^",\]\}]+\s*([,\]\}])', r'"\1', json_str)
                json_str = re.sub(r',\s*([}\]])', r'\1', json_str)
                
                # DEBUG: print(f"Website JSON extracted: {json_str[:200]}...")
                
                try:
                    result = json.loads(json_str)
                    # Validate structure
                    if isinstance(result, dict) and all(key in ['productivity', 'creativity', 'social_media_detox'] for key in result.keys()):
                        print(f"Generated website blocks for focus modes using Gemini")
                        return result
                    else:
                        print("Invalid website JSON structure returned by Gemini")
                        return {}
                except json.JSONDecodeError as e:
                    print(f"Website JSON decode error: {e}")
                    print(f"Failed website JSON: {json_str[:300]}...")
                    return {}
            else:
                print("No JSON structure found in website response")
                print(f"Website response preview: {response[:300]}...")
                return {}
                
        except Exception as e:
            print(f"Error generating website blocks with Gemini: {e}")
            return {}

    def analyze_session_goals(self, goals: List[str]) -> Dict:
        """
        Analyze session goals and return AI-powered session intelligence.
        
        Args:
            goals: List of goal strings to analyze
            
        Returns:
            Dictionary containing:
            - session_structure: List of sections with mode, duration, todos
            - total_duration: Total estimated session time in minutes
            - prioritized_goals: Goals reorganized by urgency and importance
        """
        if not self.is_available():
            print("Gemini AI service not available for session analysis")
            return self._fallback_session_analysis(goals)
        
        if not goals:
            return {
                "session_structure": [],
                "total_duration": 30,
                "prioritized_goals": []
            }
        
        try:
            import json
            import re
            
            goals_text = "\n".join([f"- {goal}" for goal in goals])
            
            system_prompt = """You are an AI productivity assistant that analyzes focus session goals and creates optimal session structures. Your task is to:

1. Estimate realistic completion times for each goal (in minutes) - BE PRECISE, avoid overestimating small tasks:
   - Quick communication (emails, messages): 2-5 minutes
   - Simple tasks (quick review, short call): 5-15 minutes
   - Focused work (document writing, analysis): 15-45 minutes
   - Deep work (research, coding, creative work): 45-120 minutes
2. Assign the best focus mode for each goal:
   - "productivity": Work tasks, coding, writing, analytical work, emails, meetings
   - "creativity": Design, brainstorming, artistic work, content creation
   - "social_media_detox": Personal tasks that don't require restricted apps, learning, reading
3. Group goals by focus mode and prioritize within each group
4. Create a session timeline with time-blocked sections

IMPORTANT: Return ONLY valid JSON in this exact format:
{
  "session_structure": [
    {
      "mode": "productivity", 
      "duration_minutes": 45,
      "todos": ["Goal 1", "Goal 2"],
      "description": "Work and analytical tasks"
    }
  ],
  "total_duration": 90,
  "prioritized_goals": [
    {
      "goal": "Goal text",
      "estimated_minutes": 20,
      "mode": "productivity",
      "priority": "high",
      "urgency_reason": "Due tomorrow"
    }
  ]
}"""

            prompt = f"""Analyze these focus session goals and create an optimal session structure:

{goals_text}

Consider:
- Realistic time estimates (be generous, people often underestimate)
- Natural task groupings by focus mode
- Urgency indicators (words like "urgent", "due", "deadline", "ASAP", "today", "tomorrow")
- Task complexity and cognitive load
- Logical work flow and momentum

Guidelines:
- Use realistic time estimates based on task complexity:
  * Quick tasks (reply to email, send message, quick call): 2-5 minutes
  * Small tasks (write short document, review file): 5-15 minutes  
  * Medium tasks (meeting, focused work session): 15-45 minutes
  * Large tasks (major project work, deep research): 45-120 minutes
- Group related tasks together for better flow
- Start with high-energy tasks when possible
- Total session should be 30-120 minutes typically
- If multiple modes needed, create separate sections
- Social Media Detox mode is for personal tasks, learning, reading that don't need restricted apps

Return ONLY the JSON structure - no explanations."""

            response = self.ask(prompt, system_prompt=system_prompt, max_tokens=2000)
            
            if not response:
                print("Empty response from Gemini for session analysis")
                return self._fallback_session_analysis(goals)
            
            # Extract JSON from response
            json_str = None
            json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', response, re.DOTALL)
            if json_match:
                json_str = json_match.group(1)
            else:
                start_idx = response.find('{')
                if start_idx != -1:
                    brace_count = 0
                    end_idx = start_idx
                    for i, char in enumerate(response[start_idx:], start_idx):
                        if char == '{':
                            brace_count += 1
                        elif char == '}':
                            brace_count -= 1
                            if brace_count == 0:
                                end_idx = i
                                break
                    if brace_count == 0:
                        json_str = response[start_idx:end_idx + 1]
            
            if json_str:
                try:
                    result = json.loads(json_str)
                    
                    # Validate required structure
                    if (isinstance(result, dict) and 
                        'session_structure' in result and 
                        'total_duration' in result and 
                        'prioritized_goals' in result):
                        
                        # Validate session structure
                        if isinstance(result['session_structure'], list):
                            for section in result['session_structure']:
                                if not all(key in section for key in ['mode', 'duration_minutes', 'todos']):
                                    print("Invalid section structure in AI response")
                                    return self._fallback_session_analysis(goals)
                        
                        print(f"Successfully analyzed {len(goals)} goals with AI")
                        return result
                    else:
                        print("Invalid JSON structure from AI session analysis")
                        return self._fallback_session_analysis(goals)
                        
                except json.JSONDecodeError as e:
                    print(f"JSON decode error in session analysis: {e}")
                    return self._fallback_session_analysis(goals)
            else:
                print("No JSON found in session analysis response")
                return self._fallback_session_analysis(goals)
                
        except Exception as e:
            print(f"Error in AI session analysis: {e}")
            return self._fallback_session_analysis(goals)
    
    def _fallback_session_analysis(self, goals: List[str]) -> Dict:
        """Fallback session analysis when AI is not available"""
        if not goals:
            return {
                "session_structure": [],
                "total_duration": 30,
                "prioritized_goals": []
            }
        
        # Simple fallback logic
        prioritized_goals = []
        total_time = 0
        
        for goal in goals:
            # Basic time estimation (15-30 minutes per goal)
            estimated_time = max(15, min(30, len(goal.split()) * 3))
            
            # Simple urgency detection
            urgency = "medium"
            urgency_reason = "Standard task"
            
            goal_lower = goal.lower()
            if any(word in goal_lower for word in ["urgent", "asap", "deadline", "due today", "due tomorrow"]):
                urgency = "high"
                urgency_reason = "Time-sensitive"
            elif any(word in goal_lower for word in ["later", "eventually", "someday"]):
                urgency = "low"
                urgency_reason = "Not time-sensitive"
            
            # Simple mode assignment (default to productivity)
            mode = "productivity"
            if any(word in goal_lower for word in ["design", "creative", "art", "draw", "music", "video", "photo"]):
                mode = "creativity"
            elif any(word in goal_lower for word in ["personal", "read", "learn", "research", "browse"]):
                mode = "social_media_detox"
            
            prioritized_goals.append({
                "goal": goal,
                "estimated_minutes": estimated_time,
                "mode": mode,
                "priority": urgency,
                "urgency_reason": urgency_reason
            })
            
            total_time += estimated_time
        
        # Group by mode
        mode_groups = {}
        for goal_data in prioritized_goals:
            mode = goal_data["mode"]
            if mode not in mode_groups:
                mode_groups[mode] = []
            mode_groups[mode].append(goal_data)
        
        # Create session structure
        session_structure = []
        mode_descriptions = {
            "productivity": "Work and analytical tasks",
            "creativity": "Creative and design work", 
            "social_media_detox": "Personal and learning tasks"
        }
        
        for mode, goals_in_mode in mode_groups.items():
            section_duration = sum(g["estimated_minutes"] for g in goals_in_mode)
            section_todos = [g["goal"] for g in goals_in_mode]
            
            session_structure.append({
                "mode": mode,
                "duration_minutes": section_duration,
                "todos": section_todos,
                "description": mode_descriptions.get(mode, "Focus tasks")
            })
        
        return {
            "session_structure": session_structure,
            "total_duration": total_time,
            "prioritized_goals": prioritized_goals
        }


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