from ai_service import ask_ai, AIService, ai_service
from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QComboBox, QPushButton, QFrame, QLineEdit, QDialog, QGraphicsDropShadowEffect,
                             QSpinBox, QTextEdit, QCheckBox, QScrollArea, QProgressBar, QGraphicsBlurEffect,
                             QSystemTrayIcon, QMenu, QAction)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QPropertyAnimation, QEasingCurve, QThread
from PyQt5.QtGui import QFont, QPalette, QColor, QPainter, QPen, QBrush, QPixmap, QRadialGradient, QIcon
import os
import subprocess
from plugin_system import PluginBase

# AI Agent which ties into todo list, installed apps, and other system features

# AI Backend

# System prompt for the AI agent
SYSTEM_PROMPT = "You are a helpful assistant for a focus app. Keep responses SHORT and casual like text messages (1-2 sentences max). " \
"Don't give long advice unless specifically asked. Be direct and helpful, not wordy." \
"You have access to many system features such as the installed and currently running applications, " \
"the user's todo list," \
" and other system information. " \
"You can also remember facts about the user to provide better assistance in the future. " \
"You should always respond in a helpful and friendly manner, and never provide harmful or dangerous advice." \
"If you feel that your response needs any of the system features, reply to the request with the following format:\n" \
"Begin your response with exactly 'SYSINFPULL:' followed by one or more of the following commands:\n" \
"  - 'installed_apps' to get a list of installed applications\n" \
"  - 'running_apps' to get a list of currently running applications\n" \
"  - 'todo_list' to get the user's todo list\n" \
"  - 'todo_completed' to get a list of todo items that have been completed\n" \
"  - 'session_length' to get the scheduled focus session length\n" \
"  - 'add_todo:<task>' to add a task to the todo list (NOTE: only works with existing session todos, cannot add new ones)\n" \
"  - 'remove_todo:<task>' to mark a task from the todo list as completed\n" \
"  - 'clear_todo' to clear the todo list\n" \
"  - 'session_time' to get the remaining time in the current focus session\n" \
"  - 'open_app:<app_name>' to open an application by name\n" \
"  - 'close_app:<app_name>' to close an application by name\n" \
" a full message might look like: 'SYSINFPULL: installed_apps, todo_list'\n" \
"CRITICAL RULES:\n" \
"1. NEVER claim you have done something unless you actually used a SYSINFPULL command to do it\n" \
"2. NEVER promise future actions like 'I'll remind you in X minutes' - you have no timer or scheduling capabilities\n" \
"3. NEVER use SYSINFPULL commands in the middle of a conversational message\n" \
"4. If you need system information, use SYSINFPULL at the START of your response, get the data, then give a complete answer\n" \
"5. Before adding new todos, always check the existing todo_list first to avoid duplicates\n" \
"6. When mentioning work on existing projects, refer to existing todo items rather than creating new ones\n" \
"7. Be proactive about suggesting and opening relevant apps, but ask for permission first\n" \
"8. Only claim capabilities you actually have through the SYSINFPULL commands\n" \
"9. NEVER use generic app names like 'writing app' - always check installed_apps to get the exact app name\n" \
"10. When opening apps, use the EXACT name from the installed_apps list\n\n" \
"For informational commands (installed_apps, running_apps, todo_list, todo_completed, session_length, session_time):\n" \
"- Use them proactively at the START of your response when the user asks about progress, productivity, apps, or session info\n" \
"- Common triggers: 'how am I doing', 'my progress', 'what apps', 'time left', 'my todos'\n" \
"- Then provide a complete conversational response based on that information\n\n" \
"For action commands (add_todo, remove_todo, clear_todo, open_app, close_app):\n" \
"1. ALWAYS check installed_apps first to see what apps are available\n" \
"2. Ask the user for permission using the EXACT app names from the installed list\n" \
"3. Wait for their approval\n" \
"4. Then execute the command by responding with ONLY 'SYSINFPULL: command' (no other text)\n" \
"5. Use the exact app name from installed_apps, not generic names\n\n" \
"When opening/closing apps, check installed_apps first to verify the app exists, then ask for permission.\n" \
"Your abilities are limited to the system features provided.\n" \
"YOU CANNOT: set timers, schedule reminders, remember things across sessions, access the internet, or perform any actions outside the SYSINFPULL commands.\n" \

HISTORY_FILE = "chat_history.txt"
MAX_HISTORY_TURNS = 10  # how many back-and-forths to keep
MEMORY_FILE = "memory.txt"  # for persistent facts

# In-memory conversation history for efficiency
_conversation_history = []

def clear_chat_history():
    """Clear chat history both in memory and file"""
    global _conversation_history
    _conversation_history = []
    if os.path.exists(HISTORY_FILE):
        os.remove(HISTORY_FILE)

def save_message(role, content):
    """Save message to both memory and file"""
    global _conversation_history
    
    # Add to memory
    _conversation_history.append({"role": role.lower(), "content": content})
    
    # Keep only recent messages in memory
    if len(_conversation_history) > MAX_HISTORY_TURNS * 2:
        _conversation_history = _conversation_history[-(MAX_HISTORY_TURNS * 2):]
    
    # Also save to file for persistence
    with open(HISTORY_FILE, "a", encoding="utf-8") as f:
        f.write(f"{role}: {content}\n")

def load_recent_history():
    """Load recent history from file into memory on first run"""
    global _conversation_history
    
    # If memory is empty, load from file
    if not _conversation_history and os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, "r", encoding="utf-8") as f:
            lines = f.readlines()
        
        # Parse file format back into message objects
        for line in lines[-(MAX_HISTORY_TURNS * 2):]:
            if ": " in line:
                role, content = line.split(": ", 1)
                role = role.lower().strip()
                # Convert old role names to proper API format
                if role in ["ai", "assistant"]:
                    role = "assistant"
                elif role == "user":
                    role = "user"
                else:
                    continue  # Skip invalid roles
                _conversation_history.append({"role": role, "content": content.strip()})
    
    return _conversation_history.copy()

def load_memory():
    if os.path.exists(MEMORY_FILE):
        with open(MEMORY_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    return ""

def get_running_apps():
    """Get list of currently running applications"""
    try:
        result = subprocess.run(['ps', '-eo', 'comm'], capture_output=True, text=True)
        apps = []
        for line in result.stdout.split('\n'):
            if line.strip() and not line.startswith('COMMAND'):
                app = line.strip()
                if '/' in app:
                    app = app.split('/')[-1]
                if app.endswith('.app'):
                    app = app[:-4]
                if app and app not in apps and not app.startswith('['):
                    apps.append(app)
        return sorted(list(set(apps)))
    except Exception as e:
        print(f"Error getting running apps: {e}")
        return []

def get_session_length(plugin_var):
    """Get the scheduled focus session length"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        return f"{plugin_var._progress_popup.session_duration} minutes"
    return "No active focus session - session length only available during focus sessions"

def add_todo_item(task, plugin_var):
    """Add a task to the todo list - currently not supported during active sessions"""
    # The current system only works with todos created during goal setup
    # New todos cannot be added during an active focus session
    return f"I can't add new todo items during an active focus session. The todo list was created when you started your session. However, I can help you work with your existing todos: {', '.join(plugin_var.get_all_checklist_items()) if hasattr(plugin_var, 'get_all_checklist_items') else 'none found'}"

def clear_todo_list(plugin_var):
    """Clear the todo list"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        # Get all current items and mark them as unchecked
        all_items = plugin_var.get_all_checklist_items()
        for item in all_items:
            plugin_var.set_checklist_item_checked(item, False)
        return f"Cleared {len(all_items)} todo items"
    return "Unable to clear todo list - no active session"

def get_remaining_session_time(plugin_var):
    """Get remaining time in current focus session"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        progress_popup = plugin_var._progress_popup
        if hasattr(progress_popup, 'start_time') and hasattr(progress_popup, 'session_duration'):
            from datetime import datetime
            elapsed = (datetime.now() - progress_popup.start_time).total_seconds() / 60  # minutes
            remaining = max(0, progress_popup.session_duration - elapsed)
            hours = int(remaining // 60)
            minutes = int(remaining % 60)
            if hours > 0:
                return f"{hours}h {minutes}m remaining"
            else:
                return f"{minutes}m remaining"
    return "No active focus session - session time only available during focus sessions"

def open_application(app_name):
    """Open an application by name"""
    try:
        subprocess.run(['open', '-a', app_name], check=True)
        return True
    except subprocess.CalledProcessError:
        try:
            # Try opening from /Applications
            subprocess.run(['open', f'/Applications/{app_name}.app'], check=True)
            return True
        except subprocess.CalledProcessError:
            print(f"Could not open application: {app_name}")
            return False

def close_application(app_name):
    """Close an application by name"""
    try:
        subprocess.run(['pkill', '-f', app_name], check=True)
        return True
    except subprocess.CalledProcessError:
        try:
            # Try with .app extension
            subprocess.run(['pkill', '-f', f"{app_name}.app"], check=True)
            return True
        except subprocess.CalledProcessError:
            print(f"Could not close application: {app_name}")
            return False

#uses plugin object to tie into plugin API calls for system info
def chat(ai, user_input, plugin_var):
    # Load conversation history
    history = load_recent_history()
    
    # Build the system prompt with memory
    memory = load_memory()
    system_prompt = SYSTEM_PROMPT
    if memory:
        system_prompt += f"\n\nPersistent facts about the user: {memory}"

    # Make the API call with conversation history
    ai_response = ai.ask(user_input, system_prompt=system_prompt, conversation_history=history)

    # Track commands used
    commands_used = []
    
    # Handle system information requests BEFORE saving messages
    if "SYSINFPULL:" in ai_response:
        # Parse commands
        commands = ai_response.split("SYSINFPULL:")[1].strip().split(",")
        commands = [cmd.strip() for cmd in commands]
        
        # Gather requested info
        info = {}
        for cmd in commands:
            if cmd == "installed_apps":
                info["installed_apps"] = ai.get_installed_applications()
                commands_used.append("checked apps")
            elif cmd == "running_apps":
                info["running_apps"] = get_running_apps()
                commands_used.append("checked running apps")
            elif cmd == "todo_list":
                info["todo_list"] = plugin_var.get_all_checklist_items()
                commands_used.append("checked todos")
            elif cmd == "session_length":
                info["session_length"] = get_session_length(plugin_var)
                commands_used.append("checked session length")
            elif cmd.startswith("add_todo:"):
                task = cmd.split("add_todo:")[1].strip()
                info["add_todo"] = add_todo_item(task, plugin_var)
                commands_used.append(f"tried to add todo")
            elif cmd.startswith("remove_todo:"):
                task = cmd.split("remove_todo:")[1].strip()
                plugin_var.set_checklist_item_checked(task, False)
                info["remove_todo"] = f"Removed todo: {task}"
                commands_used.append(f"completed todo")
            elif cmd == "clear_todo":
                info["clear_todo"] = clear_todo_list(plugin_var)
                commands_used.append("cleared todos")
            elif cmd == "session_time":
                info["session_time"] = get_remaining_session_time(plugin_var)
                commands_used.append("checked time left")
            elif cmd == "todo_completed":
                info["todo_completed"] = plugin_var.get_completed_checklist_items()
                commands_used.append("checked completed todos")
            elif cmd.startswith("open_app:"):
                app_name = cmd.split("open_app:")[1].strip()
                open_application(app_name)
                info["open_app"] = f"Opened application: {app_name}"
                commands_used.append(f"opened {app_name}")
            elif cmd.startswith("close_app:"):
                app_name = cmd.split("close_app:")[1].strip()
                close_application(app_name)
                info["close_app"] = f"Closed application: {app_name}"
                commands_used.append(f"closed {app_name}")
        
        # Create a new prompt with the gathered info and get final response
        info_prompt = "Based on the user's request, here is the system information you requested:\n"
        for key, value in info.items():
            info_prompt += f"{key}: {value}\n"
        info_prompt += "\nPlease provide a helpful response based on this information."
        
        # Get final response with the system info (no recursion)
        ai_response = ai.ask(info_prompt, system_prompt=system_prompt, conversation_history=history)

    # Save both messages only once
    save_message("user", user_input)
    save_message("assistant", ai_response)
    
    # Return response and commands used
    commands_summary = ", ".join(commands_used) if commands_used else None
    return ai_response, commands_summary



# Simple plugin implementation for standalone agent testing
class SimplePlugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.name = "Simple Agent Plugin"
    
    def initialize(self) -> bool:
        return True
    
    def cleanup(self):
        pass

#main:
if __name__ == "__main__":
    while True:
        user_input = input("You: ")
        ai = AIService()
        plugin = SimplePlugin()
        if ai.is_available():
            response = chat(ai, user_input, plugin)
            print(f"AI Response: {response}")
        else:
            print("AI service not available (check groq_api_key.txt)")