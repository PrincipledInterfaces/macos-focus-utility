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

# Enhanced System prompt for the upgraded AI agent with multi-section session support
SYSTEM_PROMPT = "You are an advanced AI assistant for a sophisticated focus app with multi-section sessions. Keep responses SHORT and casual like text messages (1-2 sentences max). " \
"Don't give long advice unless specifically asked. Be direct and helpful, not wordy." \
"You have access to comprehensive system features including installed and running applications, " \
"multi-section session management, detailed analytics, plugin integration, and advanced todo management. " \
"You can also remember facts about the user to provide better assistance in the future. " \
"You should always respond in a helpful and friendly manner, and never provide harmful or dangerous advice." \
"IMPORTANT: You can help with brainstorming, giving advice, suggesting ideas, session planning, and general conversation. " \
"Don't limit yourself to just system commands - be a helpful assistant in all ways!" \
"If you feel that your response needs any of the system features, reply to the request with the following format:\n" \
"Begin your response with exactly 'SYSINFPULL:' followed by one or more of the following commands:\n" \
"SESSION MANAGEMENT:\n" \
"  - 'session_info' to get comprehensive current session information\n" \
"  - 'section_current' to get current section details (mode, todos, time remaining)\n" \
"  - 'section_progress' to get progress across all sections\n" \
"  - 'section_jump:<index>' to jump to a specific section (0-based index)\n" \
"  - 'section_extend:<minutes>' to extend current section by X minutes\n" \
"  - 'section_complete' to mark current section as complete and move to next\n" \
"  - 'session_analytics' to get detailed session analytics and insights\n" \
"  - 'session_pause' to pause the current session (for breaks)\n" \
"  - 'session_resume' to resume a paused session\n" \
"TODO & TASK MANAGEMENT:\n" \
"  - 'todo_list' to get the user's todo list with section context\n" \
"  - 'todo_section:<section_index>' to get todos for a specific section\n" \
"  - 'todo_completed' to get completed todo items\n" \
"  - 'add_todo:<task>' to add a new task to the current section\n" \
"  - 'add_todo_section:<section_index>:<task>' to add task to specific section\n" \
"  - 'remove_todo:<task>' to mark a task as completed\n" \
"  - 'clear_todo' to clear the todo list\n" \
"  - 'todo_move:<task>:<from_section>:<to_section>' to move task between sections\n" \
"APPLICATION & SYSTEM:\n" \
"  - 'installed_apps' to get a list of installed applications\n" \
"  - 'running_apps' to get a list of currently running applications\n" \
"  - 'usage_analytics' to get app and website usage statistics for current session\n" \
"  - 'open_app:<app_name>' to open an application by name\n" \
"  - 'close_app:<app_name>' to close an application by name\n" \
"  - 'open_site:<url>' to open a website in the default browser\n" \
"  - 'focus_mode_apps:<mode>' to get apps allowed/blocked for specific focus mode\n" \
"REMINDERS & NOTIFICATIONS:\n" \
"  - 'set_reminder:<time>:<message>' to set a timed reminder (time in minutes from now)\n" \
"  - 'notify:<title>:<message>' to send immediate notification\n" \
"PLUGINS & EXTENSIONS:\n" \
"  - 'plugin_status' to get status of active plugins\n" \
"  - 'plugin_trigger:<plugin_name>:<action>' to trigger plugin actions\n" \
" a full message might look like: 'SYSINFPULL: session_info, section_current, todo_list'\n" \
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
"10. When opening apps, use the EXACT name from the installed_apps list\n" \
"11. ALWAYS check todo_list when user asks about what to work on, what's next, or needs advice\n" \
"12. Be proactive - if someone says 'you can see the list' or similar, immediately check it\n\n" \
"For informational commands (installed_apps, running_apps, todo_list, todo_completed, session_length, session_time):\n" \
"- ALWAYS use them proactively at the START of your response when they would help provide better assistance\n" \
"- Common triggers: 'how am I doing', 'my progress', 'what apps', 'time left', 'my todos', 'what's next', 'you can see', 'help me', 'advice', 'get started'\n" \
"- When in doubt, CHECK THE TODO LIST, APPS, AND OTHER INFO - it helps you give much better, more specific advice\n" \
"- Then provide a complete conversational response based on that information\n\n" \
"IMPORTANT: When user asks to ADD/CREATE new todos, use 'add_todo:<task>' NOT 'todo_list'!\n" \
"- 'add this to my todos' → use add_todo:<task>\n" \
"- 'create a todo for X' → use add_todo:<task>\n" \
"- 'remind me to do Y' → use add_todo:<task>\n" \
"- Only use 'todo_list' when user wants to SEE/CHECK existing todos\n\n" \
"If apps are open that don't appear to be relevant to the todos or session, or are seemingly unused, you can suggest closing them.\n" \
"For action commands (add_todo, remove_todo, clear_todo, open_app, close_app):\n" \
"1. ALWAYS check installed_apps first to see what apps are available\n" \
"2. Ask the user for permission using the EXACT app names from the installed list\n" \
"3. Wait for their approval\n" \
"4. Then execute the command by responding with ONLY 'SYSINFPULL: command' (no other text)\n" \
"5. Use the exact app name from installed_apps, not generic names\n\n" \
"When opening/closing apps, check installed_apps first to verify the app exists, then ask for permission.\n" \
"You have many system features available through SYSINFPULL commands, but you can also help with general conversation, brainstorming, advice, and ideas.\n" \
"YOU CANNOT: remember things across sessions, or perform system actions outside the SYSINFPULL commands.\n" \
"when the user shows desire to work on a specific thing, you can ask to close apps or websites that seem unrelated to that task.\n" \
"Opening websites relevant to the user's work or tasks is great."

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
    """Get list of currently running user-facing applications"""
    try:
        # Use ps with args to get full command paths for better filtering
        result = subprocess.run(['ps', '-eo', 'comm,args'], capture_output=True, text=True)
        apps = set()
        
        for line in result.stdout.split('\n'):
            if line.strip() and not line.startswith('COMMAND'):
                parts = line.strip().split(None, 1)
                if len(parts) >= 1:
                    comm = parts[0]
                    args = parts[1] if len(parts) > 1 else ""
                    
                    # Look for actual .app bundles in the command path
                    if '.app/Contents/MacOS/' in comm:
                        # Skip if it's an extension (.appex) or other non-main executable
                        if '.appex/' in comm or '/Extensions/' in comm or '/XPCServices/' in comm:
                            continue
                            
                        # Extract app name from path like /Applications/AppName.app/Contents/MacOS/AppName
                        app_path = comm.split('.app/Contents/MacOS/')[0] + '.app'
                        app_name = app_path.split('/')[-1].replace('.app', '')
                        
                        # Additional check: make sure the executable name matches the app name
                        # This ensures we're getting the main app executable, not a helper
                        executable_name = comm.split('/')[-1]
                        if executable_name != app_name and not executable_name.startswith(app_name):
                            continue
                        
                        # Filter out obvious background processes and system utilities
                        if not any(skip in app_name.lower() for skip in [
                            'agent', 'helper', 'service', 'daemon', 'sync', 'extension',
                            'background', 'launcher', 'processor', 'monitor', 'updater',
                            'notification', 'widget', 'plugin', 'framework', 'crashreporter',
                            'diagnostics', 'configuration', 'subscriber', 'broker'
                        ]):
                            apps.add(app_name)
                    
                    # Also check if it's a direct app launch (like /Applications/AppName.app)
                    elif '.app' in args and '/Applications/' in args:
                        # Skip if this is an extension or helper process
                        if '.appex/' in args or '/Extensions/' in args or '/XPCServices/' in args:
                            continue
                            
                        import re
                        app_match = re.search(r'/Applications/([^/]+\.app)', args)
                        if app_match:
                            app_name = app_match.group(1).replace('.app', '')
                            if not any(skip in app_name.lower() for skip in [
                                'agent', 'helper', 'service', 'daemon', 'sync', 'extension',
                                'background', 'launcher', 'processor', 'monitor', 'updater',
                                'notification', 'widget', 'plugin', 'framework', 'crashreporter',
                                'diagnostics', 'configuration', 'subscriber', 'broker'
                            ]):
                                apps.add(app_name)
        
        return sorted(list(apps))
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
    print(f"DEBUG: add_todo_item called with task='{task}', plugin_var type={type(plugin_var)}")
    print(f"DEBUG: plugin_var has add_checklist_item: {hasattr(plugin_var, 'add_checklist_item')}")
    print(f"DEBUG: plugin_var has _progress_popup: {hasattr(plugin_var, '_progress_popup')}")
    if hasattr(plugin_var, '_progress_popup'):
        print(f"DEBUG: _progress_popup is: {plugin_var._progress_popup}")
    
    if hasattr(plugin_var, 'add_checklist_item'):
        # Use the proper plugin API method
        print(f"DEBUG: Calling plugin_var.add_checklist_item('{task}')")
        success = plugin_var.add_checklist_item(task)
        print(f"DEBUG: add_checklist_item returned: {success}")
        if success:
            formatted_task = task if task.startswith('•') else f"• {task}"
            return f"Added new todo: {formatted_task}"
        else:
            return "Failed to add todo item - check if focus session is active"
    
    return "Unable to add todo - no active focus session or missing add_checklist_item method"

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

# NEW ENHANCED FUNCTIONS FOR MULTI-SECTION SESSIONS

def get_session_info(plugin_var):
    """Get comprehensive session information"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            current_section = manager.current_section_index + 1
            total_sections = len(manager.session_structure)
            progress = manager.get_overall_progress() * 100
            
            return f"""📊 Session Overview:
• Progress: {progress:.1f}% complete
• Section: {current_section} of {total_sections}
• Total Time: {manager.get_total_elapsed_time():.0f} minutes elapsed
• Sections Complete: {current_section - 1}"""
    return "No multi-section session active"

def get_current_section_info(plugin_var):
    """Get detailed info about current section"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            if manager.current_section_index < len(manager.session_structure):
                section = manager.session_structure[manager.current_section_index]
                mode_names = {
                    "productivity": "🏢 Productivity",
                    "creativity": "🎨 Creativity",
                    "social_media_detox": "🧘 Social Media Detox"
                }
                mode_name = mode_names.get(section['mode'], section['mode'].title())
                
                todos = section.get('todos', [])
                todo_list = "\n".join([f"• {todo}" for todo in todos]) if todos else "No todos"
                
                return f"""📍 Current Section ({manager.current_section_index + 1}):
• Mode: {mode_name}
• Duration: {section.get('duration_minutes', 0)} minutes
• Todos: 
{todo_list}"""
    return "No current section info available"

def send_notification(title, message):
    """Send a system notification"""
    try:
        import subprocess
        script = f'''
            display notification "{message}" with title "{title}"
        '''
        subprocess.run(['osascript', '-e', script], check=True)
        return f"📱 Notification sent: {title}"
    except Exception as e:
        return f"❌ Failed to send notification: {e}"

def get_plugin_status():
    """Get status of active plugins"""
    try:
        from plugin_system import plugin_manager
        enabled_plugins = plugin_manager.get_enabled_plugins()
        if enabled_plugins:
            plugin_list = "\n".join([f"• {plugin}: Enabled" for plugin in enabled_plugins])
            return f"🔌 Active Plugins:\n{plugin_list}"
        else:
            return "🔌 No plugins currently enabled"
    except Exception as e:
        return f"❌ Error checking plugin status: {e}"

def get_usage_analytics(plugin_var):
    """Get app and website usage statistics"""
    try:
        import os
        from collections import Counter
        
        script_dir = os.path.dirname(os.path.abspath(__file__))
        apps_log = os.path.join(script_dir, 'active_programs.log')
        tabs_log = os.path.join(script_dir, 'browser_tabs.log')
        
        usage_info = []
        
        # Parse apps usage
        if os.path.exists(apps_log):
            app_counts = Counter()
            with open(apps_log, 'r') as f:
                for line in f:
                    if 'Active Programs:' in line:
                        apps_part = line.split('Active Programs:')[1].strip()
                        if apps_part and apps_part != '{}':
                            apps = [app.strip() for app in apps_part.replace('{', '').replace('}', '').split(',')]
                            for app in apps:
                                if app and app not in ['Finder', 'Dock', 'SystemUIServer']:
                                    app_counts[app.strip()] += 1
            
            if app_counts:
                top_apps = app_counts.most_common(5)
                usage_info.append("📱 Top Apps:")
                for app, count in top_apps:
                    usage_info.append(f"  • {app}: {count} instances")
        
        return "\n".join(usage_info) if usage_info else "No usage data available"
        
    except Exception as e:
        return f"❌ Error getting usage analytics: {e}"

def get_section_progress(plugin_var):
    """Get progress across all sections"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            total_sections = len(manager.session_structure)
            current_section = manager.current_section_index + 1
            completed_sections = manager.current_section_index
            overall_progress = manager.get_overall_progress() * 100
            
            progress_info = []
            progress_info.append(f"📊 Section Progress:")
            progress_info.append(f"• Overall: {overall_progress:.1f}% complete")
            progress_info.append(f"• Current: Section {current_section} of {total_sections}")
            progress_info.append(f"• Completed: {completed_sections} sections")
            progress_info.append(f"• Remaining: {total_sections - current_section} sections")
            
            # Show section details
            for i, section in enumerate(manager.session_structure):
                status = "✅" if i < manager.current_section_index else "🔄" if i == manager.current_section_index else "⏳"
                mode_names = {
                    "productivity": "🏢",
                    "creativity": "🎨", 
                    "social_media_detox": "🧘"
                }
                icon = mode_names.get(section['mode'], "📋")
                progress_info.append(f"  {status} {icon} {section.get('duration_minutes', 0)}m - {len(section.get('todos', []))} todos")
            
            return "\n".join(progress_info)
    return "No section progress available"

def jump_to_section(section_index, plugin_var):
    """Jump to a specific section"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            if 0 <= section_index < len(manager.session_structure):
                try:
                    # Use the session manager's jump functionality if available
                    if hasattr(manager, 'jump_to_section'):
                        success = manager.jump_to_section(section_index)
                        if success:
                            return f"✅ Jumped to section {section_index + 1}"
                        else:
                            return f"❌ Failed to jump to section {section_index + 1}"
                    else:
                        # Direct section change
                        old_section = manager.current_section_index + 1
                        manager.current_section_index = section_index
                        return f"✅ Switched from section {old_section} to {section_index + 1}"
                except Exception as e:
                    return f"❌ Error jumping to section: {e}"
            else:
                return f"❌ Invalid section index {section_index + 1}. Valid range: 1-{len(manager.session_structure)}"
    return "❌ Cannot jump sections - no active session"

def extend_current_section(minutes, plugin_var):
    """Extend current section by X minutes"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            if manager.current_section_index < len(manager.session_structure):
                section = manager.session_structure[manager.current_section_index]
                old_duration = section.get('duration_minutes', 0)
                section['duration_minutes'] = old_duration + minutes
                
                # Update session duration if available
                if hasattr(popup, 'session_duration'):
                    popup.session_duration += minutes
                
                return f"✅ Extended current section by {minutes} minutes ({old_duration}m → {section['duration_minutes']}m)"
    return "❌ Cannot extend section - no active session"

def complete_current_section(plugin_var):
    """Complete current section and move to next"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            current_section = manager.current_section_index + 1
            
            # Use session manager's complete section method if available
            if hasattr(manager, 'complete_current_section'):
                try:
                    success = manager.complete_current_section()
                    if success:
                        if manager.current_section_index < len(manager.session_structure):
                            return f"✅ Completed section {current_section}, moved to section {manager.current_section_index + 1}"
                        else:
                            return f"✅ Completed final section {current_section} - session complete!"
                    else:
                        return f"❌ Failed to complete section {current_section}"
                except Exception as e:
                    return f"❌ Error completing section: {e}"
            else:
                # Basic section advancement
                if manager.current_section_index < len(manager.session_structure) - 1:
                    manager.current_section_index += 1
                    return f"✅ Advanced from section {current_section} to {manager.current_section_index + 1}"
                else:
                    return f"✅ Already at final section ({current_section})"
    return "❌ Cannot complete section - no active session"

def get_session_analytics(plugin_var):
    """Get detailed session analytics and insights"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        analytics = ["📊 Session Analytics:"]
        
        # Basic session info
        if hasattr(popup, 'start_time'):
            from datetime import datetime
            elapsed_minutes = (datetime.now() - popup.start_time).total_seconds() / 60
            analytics.append(f"• Active Time: {elapsed_minutes:.1f} minutes")
        
        if hasattr(popup, 'session_duration'):
            analytics.append(f"• Planned Duration: {popup.session_duration} minutes")
        
        # Multi-section analytics
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            analytics.append(f"• Sections: {manager.current_section_index + 1} of {len(manager.session_structure)}")
            
            # Mode distribution
            mode_counts = {}
            total_todos = 0
            for section in manager.session_structure:
                mode = section.get('mode', 'unknown')
                mode_counts[mode] = mode_counts.get(mode, 0) + 1
                total_todos += len(section.get('todos', []))
            
            analytics.append(f"• Total Todos: {total_todos}")
            analytics.append("• Mode Distribution:")
            for mode, count in mode_counts.items():
                mode_names = {
                    "productivity": "🏢 Productivity",
                    "creativity": "🎨 Creativity",
                    "social_media_detox": "🧘 Detox"
                }
                analytics.append(f"  - {mode_names.get(mode, mode.title())}: {count} sections")
        
        # Usage analytics
        usage_stats = get_usage_analytics(plugin_var)
        if "No usage data available" not in usage_stats:
            analytics.append("\n" + usage_stats)
        
        return "\n".join(analytics)
    return "No session analytics available"

def pause_session(plugin_var):
    """Pause the current session"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'pause_session'):
            popup.pause_session()
            return "⏸️ Session paused"
        else:
            return "⚠️ Session pause not supported in this version"
    return "❌ Cannot pause - no active session"

def resume_session(plugin_var):
    """Resume a paused session"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'resume_session'):
            popup.resume_session()
            return "▶️ Session resumed"
        else:
            return "⚠️ Session resume not supported in this version"
    return "❌ Cannot resume - no active session"

def get_section_todos(section_index, plugin_var):
    """Get todos for a specific section"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            if 0 <= section_index < len(manager.session_structure):
                section = manager.session_structure[section_index]
                todos = section.get('todos', [])
                mode = section.get('mode', 'unknown')
                
                mode_names = {
                    "productivity": "🏢 Productivity",
                    "creativity": "🎨 Creativity", 
                    "social_media_detox": "🧘 Social Media Detox"
                }
                mode_name = mode_names.get(mode, mode.title())
                
                if todos:
                    todo_list = "\n".join([f"• {todo}" for todo in todos])
                    return f"📋 Section {section_index + 1} ({mode_name}):\n{todo_list}"
                else:
                    return f"📋 Section {section_index + 1} ({mode_name}): No todos"
            else:
                return f"❌ Invalid section index. Valid range: 1-{len(manager.session_structure)}"
    return "❌ Cannot get section todos - no active session"

def add_todo_to_section(section_index, task, plugin_var):
    """Add a todo to a specific section"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            if 0 <= section_index < len(manager.session_structure):
                section = manager.session_structure[section_index]
                if 'todos' not in section:
                    section['todos'] = []
                section['todos'].append(task)
                return f"✅ Added '{task}' to section {section_index + 1}"
            else:
                return f"❌ Invalid section index. Valid range: 1-{len(manager.session_structure)}"
    return "❌ Cannot add todo to section - no active session"

def move_todo_between_sections(task, from_section, to_section, plugin_var):
    """Move a todo between sections"""
    if hasattr(plugin_var, '_progress_popup') and plugin_var._progress_popup:
        popup = plugin_var._progress_popup
        if hasattr(popup, 'session_manager') and popup.session_manager:
            manager = popup.session_manager
            max_sections = len(manager.session_structure)
            
            if not (0 <= from_section < max_sections and 0 <= to_section < max_sections):
                return f"❌ Invalid section indices. Valid range: 1-{max_sections}"
            
            from_sec = manager.session_structure[from_section]
            to_sec = manager.session_structure[to_section]
            
            # Find and remove task from source section
            if 'todos' in from_sec and task in from_sec['todos']:
                from_sec['todos'].remove(task)
                
                # Add to destination section
                if 'todos' not in to_sec:
                    to_sec['todos'] = []
                to_sec['todos'].append(task)
                
                return f"✅ Moved '{task}' from section {from_section + 1} to {to_section + 1}"
            else:
                available_todos = from_sec.get('todos', [])
                return f"❌ Todo '{task}' not found in section {from_section + 1}. Available: {', '.join(available_todos)}"
    return "❌ Cannot move todo - no active session"

def get_focus_mode_apps(mode):
    """Get apps allowed/blocked for specific focus mode"""
    try:
        from gemini_service import gemini_service
        # Get installed apps
        installed_apps = gemini_service.get_installed_applications()
        
        # Categorize apps
        categorized = gemini_service.categorize_apps_for_modes(installed_apps)
        
        mode_apps = categorized.get(mode, [])
        if mode_apps:
            app_list = "\n".join([f"• {app}" for app in mode_apps])
            mode_names = {
                "productivity": "🏢 Productivity",
                "creativity": "🎨 Creativity",
                "social_media_detox": "🧘 Social Media Detox"
            }
            mode_name = mode_names.get(mode, mode.title())
            return f"📱 {mode_name} Mode Apps:\n{app_list}"
        else:
            return f"❌ No apps categorized for {mode} mode"
    except Exception as e:
        return f"❌ Error getting focus mode apps: {e}"

def trigger_plugin_action(plugin_name, action):
    """Trigger a plugin action"""
    try:
        from plugin_system import plugin_manager
        plugins = plugin_manager.get_enabled_plugins()
        
        if plugin_name in plugins:
            plugin = plugins[plugin_name]
            if hasattr(plugin, action):
                result = getattr(plugin, action)()
                return f"🔌 Triggered {action} on {plugin_name}: {result}"
            else:
                available_methods = [method for method in dir(plugin) if not method.startswith('_')]
                return f"❌ Action '{action}' not found on {plugin_name}. Available: {', '.join(available_methods)}"
        else:
            return f"❌ Plugin '{plugin_name}' not found or not enabled"
    except Exception as e:
        return f"❌ Error triggering plugin action: {e}"

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
                result = add_todo_item(task, plugin_var)
                info["add_todo"] = result
                if "Added new todo:" in result:
                    commands_used.append(f"successfully added todo '{task}'")
                else:
                    commands_used.append(f"failed to add todo '{task}' - {result}")
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
            
            # NEW ENHANCED COMMANDS FOR MULTI-SECTION SESSIONS
            elif cmd == "session_info":
                info["session_info"] = get_session_info(plugin_var)
                commands_used.append("checked session info")
            elif cmd == "section_current":
                info["section_current"] = get_current_section_info(plugin_var)
                commands_used.append("checked current section")
            elif cmd == "section_progress":
                info["section_progress"] = get_section_progress(plugin_var)
                commands_used.append("checked section progress")
            elif cmd.startswith("section_jump:"):
                section_index = int(cmd.split("section_jump:")[1].strip())
                result = jump_to_section(section_index, plugin_var)
                info["section_jump"] = result
                commands_used.append(f"jumped to section {section_index + 1}")
            elif cmd.startswith("section_extend:"):
                minutes = int(cmd.split("section_extend:")[1].strip())
                result = extend_current_section(minutes, plugin_var)
                info["section_extend"] = result
                commands_used.append(f"extended section by {minutes}m")
            elif cmd == "section_complete":
                result = complete_current_section(plugin_var)
                info["section_complete"] = result
                commands_used.append("completed current section")
            elif cmd == "session_analytics":
                info["session_analytics"] = get_session_analytics(plugin_var)
                commands_used.append("checked session analytics")
            elif cmd == "session_pause":
                result = pause_session(plugin_var)
                info["session_pause"] = result
                commands_used.append("paused session")
            elif cmd == "session_resume":
                result = resume_session(plugin_var)
                info["session_resume"] = result
                commands_used.append("resumed session")
            elif cmd.startswith("todo_section:"):
                section_index = int(cmd.split("todo_section:")[1].strip())
                info["todo_section"] = get_section_todos(section_index, plugin_var)
                commands_used.append(f"checked todos for section {section_index + 1}")
            elif cmd.startswith("add_todo_section:"):
                parts = cmd.split("add_todo_section:")[1].strip().split(":", 1)
                if len(parts) == 2:
                    section_index = int(parts[0].strip())
                    task = parts[1].strip()
                    result = add_todo_to_section(section_index, task, plugin_var)
                    info["add_todo_section"] = result
                    commands_used.append(f"added todo to section {section_index + 1}")
            elif cmd.startswith("todo_move:"):
                parts = cmd.split("todo_move:")[1].strip().split(":")
                if len(parts) == 3:
                    task, from_section, to_section = parts
                    result = move_todo_between_sections(task.strip(), int(from_section.strip()), int(to_section.strip()), plugin_var)
                    info["todo_move"] = result
                    commands_used.append(f"moved todo between sections")
            elif cmd == "usage_analytics":
                info["usage_analytics"] = get_usage_analytics(plugin_var)
                commands_used.append("checked usage analytics")
            elif cmd.startswith("focus_mode_apps:"):
                mode = cmd.split("focus_mode_apps:")[1].strip()
                info["focus_mode_apps"] = get_focus_mode_apps(mode)
                commands_used.append(f"checked {mode} mode apps")
            elif cmd.startswith("notify:"):
                parts = cmd.split("notify:")[1].strip().split(":", 1)
                if len(parts) == 2:
                    title, message = parts
                    result = send_notification(title.strip(), message.strip())
                    info["notify"] = result
                    commands_used.append("sent notification")
            elif cmd == "plugin_status":
                info["plugin_status"] = get_plugin_status()
                commands_used.append("checked plugin status")
            elif cmd.startswith("plugin_trigger:"):
                parts = cmd.split("plugin_trigger:")[1].strip().split(":", 1)
                if len(parts) == 2:
                    plugin_name, action = parts
                    result = trigger_plugin_action(plugin_name.strip(), action.strip())
                    info["plugin_trigger"] = result
                    commands_used.append(f"triggered {plugin_name} plugin")
                else:
                    info["set_reminder"] = "Invalid reminder format. Use: set_reminder:15:Check the oven"
                    commands_used.append("failed to set reminder - invalid format")
        
        # Create a new prompt with the gathered info and get final response
        info_prompt = f"The user asked: '{user_input}'\n\nI executed these system commands and got these results:\n"
        for key, value in info.items():
            info_prompt += f"- {key}: {value}\n"
        info_prompt += "\nNow provide a SHORT, casual response (like a text message) confirming what was done. Be friendly and conversational. NEVER use SYSINFPULL commands in your response - just tell the user what happened in plain English."
        
        # Get final response with the system info (no recursion)
        ai_response = ai.ask(info_prompt, system_prompt=system_prompt, conversation_history=history)
        print(f"DEBUG: Final AI response after SYSINFPULL: '{ai_response}'")
        
        # If AI still responds with SYSINFPULL, provide a contextual fallback
        if "SYSINFPULL:" in ai_response:
            print("DEBUG: AI responded with SYSINFPULL again, using contextual fallback")
            # Provide a more helpful response based on the user's input
            if "todo" in user_input.lower() or "task" in user_input.lower():
                ai_response = "I can see your todo list! Is there a specific task you'd like help with or want me to analyze?"
            elif "progress" in user_input.lower() or "status" in user_input.lower():
                ai_response = "I can help track your progress! What would you like to know about your current session?"
            elif "focus" in user_input.lower() or "session" in user_input.lower():
                ai_response = "I'm here to help you stay focused! How can I assist with your current session?"
            else:
                ai_response = "I'm here to help! Could you be more specific about what you'd like assistance with?"

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