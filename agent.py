from gemini_service import ask_gemini, GeminiService, gemini_service
from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QComboBox, QPushButton, QFrame, QLineEdit, QDialog, QGraphicsDropShadowEffect,
                             QSpinBox, QTextEdit, QCheckBox, QScrollArea, QProgressBar, QGraphicsBlurEffect,
                             QSystemTrayIcon, QMenu, QAction)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QPropertyAnimation, QEasingCurve, QThread
from PyQt5.QtGui import QFont, QPalette, QColor, QPainter, QPen, QBrush, QPixmap, QRadialGradient, QIcon
import os
import subprocess
from plugin_system import PluginBase
from agent_timer import set_timer

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
"  - 'add_todo:<task>' to add a new task to the todo list\n" \
"  - 'remove_todo:<task>' to mark a task from the todo list as completed\n" \
"  - 'clear_todo' to clear the todo list\n" \
"  - 'session_time' to get the remaining time in the current focus session\n" \
"  - 'open_app:<app_name>' to open an application by name\n" \
"  - 'close_app:<app_name>' to close an application by name\n" \
"  - 'open_site:<url>' to open a website in the default browser\n" \
"  - 'set_reminder:<time>:<message>' Example: set_reminder:15:Check the oven. Note: <time> is the number of minutes from the current time, not a clock time like 3:00 PM.\n" \
" a full message might look like: 'SYSINFPULL: installed_apps, todo_list'\n" \
"CRITICAL RULES:\n" \
"1. NEVER claim you have done something unless you actually used a SYSINFPULL command to do it\n" \
"2. NEVER promise future actions like 'I'll remind you in X minutes' - you have no timer or scheduling capabilities\n" \
"3. NEVER use SYSINFPULL commands in the middle of a conversational message\n" \
"4. If you need system information, use SYSINFPULL at the START of your response, get the data, then give a complete answer\n" \
"5. Before adding new todos, always check the existing todo_list first to avoid duplicates\n" \
"6. When mentioning work on existing projects, refer to existing todo items rather than creating new ones\n" \
"7. Be proactive about suggesting, closing and opening relevant apps, but ask for permission first\n" \
"8. Only claim capabilities you actually have through the SYSINFPULL commands\n" \
"9. NEVER use generic app names like 'writing app' - always check installed_apps to get the exact app name\n" \
"10. When opening apps, use the EXACT name from the installed_apps list\n\n" \
"For informational commands (installed_apps, running_apps, todo_list, todo_completed, session_length, session_time):\n" \
"- Use them proactively at the START of your response when the user asks about progress, productivity, apps, or session info\n" \
"- Common triggers: 'how am I doing', 'my progress', 'what apps', 'time left', 'my todos'\n" \
"- Then provide a complete conversational response based on that information\n\n" \
"If apps are open that don't appear to be relevant to the todos or session, or are seemingly unused, you can suggest closing them.\n" \
"For action commands (add_todo, remove_todo, clear_todo, open_app, close_app):\n" \
"1. ALWAYS check installed_apps first to see what apps are available\n" \
"2. Ask the user for permission using the EXACT app names from the installed list\n" \
"3. Wait for their approval\n" \
"4. Then execute the command by responding with ONLY 'SYSINFPULL: command' (no other text)\n" \
"5. Use the exact app name from installed_apps, not generic names\n\n" \
"When opening/closing apps, check installed_apps first to verify the app exists, then ask for permission.\n" \
"Your abilities are limited to the system features provided.\n" \
"YOU CANNOT: remember things across sessions, or perform any actions outside the SYSINFPULL commands.\n" \
"when the user shows desire to work on a specific thing, you can ask to close apps or websites that seem unrelated to that task.\n" \

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
    """Add a task to the todo list"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        progress_popup = plugin_var._progress_popup
        
        # Format task with bullet point if it doesn't have one
        formatted_task = task if task.startswith('•') else f"• {task}"
        
        # Add to goals list
        progress_popup.goals.append(formatted_task)
        
        # Add checkbox to UI if the goals layout exists
        if hasattr(progress_popup, 'goals_layout') and hasattr(progress_popup, 'goal_checkboxes'):
            from PyQt5.QtWidgets import QCheckBox
            checkbox = QCheckBox(formatted_task)
            checkbox.setStyleSheet("""
                QCheckBox {
                    font-size: 14px;
                    color: #1d1d1f;
                    padding: 8px 12px;
                    background: rgba(255, 255, 255, 0.8);
                    border-radius: 8px;
                    margin: 2px 0;
                }
                QCheckBox::indicator {
                    width: 16px;
                    height: 16px;
                    margin-right: 8px;
                }
                QCheckBox::indicator:unchecked {
                    border: 2px solid #d1d1d6;
                    border-radius: 4px;
                    background: white;
                }
                QCheckBox::indicator:checked {
                    border: 2px solid #007aff;
                    border-radius: 4px;
                    background: #007aff;
                    image: url(data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIiIGhlaWdodD0iMTIiIHZpZXdCb3g9IjAgMCAxMiAxMiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEwIDNMNC41IDguNUwyIDYiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+Cjwvc3ZnPgo=);
                }
            """)
            checkbox.stateChanged.connect(progress_popup.goal_checked)
            
            # Insert before the last item (stretch) in the layout
            insert_index = progress_popup.goals_layout.count() - 1
            progress_popup.goals_layout.insertWidget(insert_index, checkbox)
            progress_popup.goal_checkboxes.append(checkbox)
        
        return f"Added new todo: {formatted_task}"
    
    return "Unable to add todo - no active focus session"

def complete_todo_item(task, plugin_var):
    """Mark a todo item as completed with improved matching"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        # Try multiple matching strategies
        all_items = plugin_var.get_all_checklist_items()
        
        for item in all_items:
            # Strategy 1: Exact match
            if item == task:
                return plugin_var.set_checklist_item_checked(item, True)
            
            # Strategy 2: Match without bullet point
            if item.startswith('• ') and item[2:] == task:
                return plugin_var.set_checklist_item_checked(item, True)
            
            # Strategy 3: Match with added bullet point
            if task.startswith('• ') and item == task[2:]:
                return plugin_var.set_checklist_item_checked(item, True)
                
            # Strategy 4: Case insensitive partial match
            if task.lower() in item.lower() or item.lower() in task.lower():
                # Only use partial match if it's a substantial portion (>50% of the shorter string)
                min_len = min(len(task.strip('• ')), len(item.strip('• ')))
                if min_len > 5:  # Only for longer strings
                    return plugin_var.set_checklist_item_checked(item, True)
        
        return False
    
    return False

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
                success = complete_todo_item(task, plugin_var)
                if success:
                    info["remove_todo"] = f"Completed todo: {task}"
                    commands_used.append(f"completed todo")
                else:
                    info["remove_todo"] = f"Could not find todo to complete: {task}. Available todos: {', '.join(plugin_var.get_all_checklist_items()) if hasattr(plugin_var, 'get_all_checklist_items') else 'none found'}"
                    commands_used.append(f"failed to complete todo")
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
            elif cmd.startswith("open_site:"):
                url = cmd.split("open_site:")[1].strip()
                try:
                    # Fix URL formatting if needed
                    if not url.startswith(('http://', 'https://')):
                        if '.' in url and not url.startswith('www.'):
                            url = f"https://{url}"
                        elif url.startswith('www.'):
                            url = f"https://{url}"
                        else:
                            url = f"https://www.google.com/search?q={url}"
                    
                    result = subprocess.run(['open', url], check=True, capture_output=True, text=True)
                    info["open_site"] = f"Opened website: {url}"
                    commands_used.append(f"opened site {url}")
                except subprocess.CalledProcessError as e:
                    error_msg = f"Failed to open website: {url} (Error: {e.stderr if hasattr(e, 'stderr') else str(e)})"
                    info["open_site"] = error_msg
                    commands_used.append(f"failed to open site {url}")
                except Exception as e:
                    error_msg = f"Failed to open website: {url} (Error: {str(e)})"
                    info["open_site"] = error_msg
                    commands_used.append(f"failed to open site {url}")
            elif cmd.startswith("set_reminder:"):
                parts = cmd.split("set_reminder:")[1].strip().split(":")
                if len(parts) >= 2:
                    try:
                        time_str = parts[0].strip()
                        message = ":".join(parts[1:]).strip()  # Handle messages with colons
                        
                        # Validate time is a number
                        time_minutes = float(time_str)
                        if time_minutes <= 0:
                            raise ValueError("Time must be positive")
                        if time_minutes > 1440:  # More than 24 hours
                            raise ValueError("Time must be less than 24 hours")
                        
                        set_timer(time_minutes, message)
                        info["set_reminder"] = f"Reminder set for {time_minutes} minutes: {message}"
                        commands_used.append(f"set reminder for {time_minutes} minutes")
                        
                    except ValueError as e:
                        error_msg = f"Invalid time format '{parts[0]}': {str(e)}"
                        info["set_reminder"] = error_msg
                        commands_used.append("failed to set reminder - invalid time")
                    except Exception as e:
                        error_msg = f"Error setting reminder: {str(e)}"
                        info["set_reminder"] = error_msg
                        commands_used.append("failed to set reminder")
                else:
                    info["set_reminder"] = "Invalid reminder format. Use: set_reminder:15:Check the oven"
                    commands_used.append("failed to set reminder - invalid format")
        
        # Create a new prompt with the gathered info and get final response
        info_prompt = f"The user asked: '{user_input}'\n\nBased on this request, here is the system information you requested:\n"
        for key, value in info.items():
            info_prompt += f"{key}: {value}\n"
        info_prompt += "\nPlease provide a helpful response to the user's original request based on this information."
        
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
        ai = GeminiService()
        plugin = SimplePlugin()
        if ai.is_available():
            response, commands = chat(ai, user_input, plugin)
            print(f"AI Response: {response}")
            if commands:
                print(f"Commands used: {commands}")
        else:
            print("AI service not available (check gemini_api_key.txt)")