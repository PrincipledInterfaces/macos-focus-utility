# Focus Utility - Plugin Development Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Plugin Architecture Overview](#plugin-architecture-overview)
3. [Quick Start Guide](#quick-start-guide)
4. [Plugin Structure](#plugin-structure)
5. [API Reference](#api-reference)
6. [Hook System](#hook-system)
7. [Configuration Management](#configuration-management)
8. [UI Integration](#ui-integration)
9. [Testing and Debugging](#testing-and-debugging)
10. [Best Practices](#best-practices)
11. [Advanced Topics](#advanced-topics)
12. [Example Plugins](#example-plugins)
13. [Troubleshooting](#troubleshooting)

---

## Introduction

Welcome to the Focus Utility Plugin Development Guide! This document provides comprehensive information for developers who want to create plugins that extend the functionality of the Focus Utility application.

### What Can Plugins Do?

Plugins can:
- **Analyze user goals** and add new tasks based on external data sources
- **Monitor sessions** and provide real-time feedback
- **Integrate with external services** (email, calendars, task managers, etc.)
- **Extend the UI** with configuration dialogs and status displays
- **React to session events** (start, update, end)
- **Send notifications** during focus sessions

### Prerequisites

- **Python 3.7+** with PyQt5
- **Basic understanding** of object-oriented programming
- **Familiarity** with Python imports and modules
- **Knowledge** of JSON for configuration files

---

## Plugin Architecture Overview

### Core Concepts

The Focus Utility plugin system is built on several key principles:

1. **Abstract Base Classes**: All plugins inherit from `PluginBase`
2. **Hook-Based Events**: Plugins respond to application events through hooks
3. **Dynamic Loading**: Plugins are discovered and loaded at runtime
4. **Fail-Safe Operation**: Plugin failures don't crash the main application
5. **Hot-Swappable**: Plugins can be enabled/disabled without restarting

### Plugin Lifecycle

```
Discovery → Loading → Initialization → Active → Cleanup
```

1. **Discovery**: Plugin directories are scanned for `manifest.json` files
2. **Loading**: Python modules are dynamically imported
3. **Initialization**: Plugin's `initialize()` method is called
4. **Active**: Plugin responds to hooks and provides functionality
5. **Cleanup**: Plugin's `cleanup()` method is called when disabled

### Communication Model

```
Main Application ←→ Plugin Manager ←→ Individual Plugins
                        ↓
                   Hook Broadcasting
                        ↓
              Plugin-Specific Handlers
```

---

## Quick Start Guide

### Creating Your First Plugin

Let's create a simple "Hello World" plugin:

#### Step 1: Create Plugin Directory
```bash
mkdir plugins/hello_world
cd plugins/hello_world
```

#### Step 2: Create Manifest File
Create `manifest.json`:
```json
{
  "name": "Hello World",
  "version": "1.0.0",
  "description": "A simple example plugin that demonstrates basic functionality",
  "main_file": "plugin.py",
  "author": "Your Name",
  "requires": [],
  "permissions": ["notifications"]
}
```

#### Step 3: Create Plugin Implementation
Create `plugin.py`:
```python
#!/usr/bin/env python3

import os
import sys
from typing import List, Dict, Any

# Add parent directory to path to import plugin_system
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from plugin_system import PluginBase

class Plugin(PluginBase):
    """Hello World Plugin - Demonstrates basic plugin functionality"""
    
    def __init__(self):
        super().__init__()
        self.name = "Hello World"
        self.version = "1.0.0"
        self.description = "A simple example plugin"
    
    def initialize(self) -> bool:
        """Initialize the plugin"""
        print(f"Hello World plugin initialized!")
        return True
    
    def cleanup(self):
        """Cleanup when plugin is disabled"""
        print("Hello World plugin cleanup completed")
    
    def on_session_start(self, session_data: Dict[str, Any]):
        """Called when focus session starts"""
        print(f"Hello World: Focus session started!")
        print(f"Session mode: {session_data.get('mode', 'unknown')}")
        print(f"Session duration: {session_data.get('duration_minutes', 0)} minutes")
    
    def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
        """Called after goals are analyzed - can modify goals list"""
        # Add a motivational message to the goals
        enhanced_goals = goals.copy()
        enhanced_goals.append("• Stay motivated and focused! 💪")
        
        print(f"Hello World: Added motivational message to {len(goals)} goals")
        return enhanced_goals
    
    def on_session_end(self, session_data: Dict[str, Any]):
        """Called when session completes"""
        elapsed = session_data.get('elapsed_minutes', 0)
        print(f"Hello World: Congratulations! You focused for {elapsed} minutes!")
```

#### Step 4: Test Your Plugin

1. Start the Focus Utility application
2. Open Plugin Settings (you'll see your plugin listed)
3. Enable the "Hello World" plugin
4. Start a focus session and observe the console output

---

## Plugin Structure

### Required Files

Every plugin must have:

#### 1. Plugin Directory
```
plugins/
  your_plugin_name/
    ├── manifest.json       # Plugin metadata (required)
    ├── plugin.py          # Main implementation (required)
    ├── __init__.py        # Makes it a Python package (optional)
    ├── config.json        # Plugin configuration (optional)
    └── README.md          # Documentation (recommended)
```

#### 2. Manifest File (`manifest.json`)
```json
{
  "name": "Your Plugin Name",
  "version": "1.0.0",
  "description": "Brief description of what your plugin does",
  "main_file": "plugin.py",
  "author": "Your Name",
  "email": "your.email@example.com",
  "website": "https://your-website.com",
  "requires": ["requests", "beautifulsoup4"],
  "permissions": ["notifications", "network_access", "file_system"],
  "min_app_version": "1.0.0",
  "max_app_version": "2.0.0"
}
```

**Manifest Fields:**
- `name` (required): Display name for the plugin
- `version` (required): Semantic version (X.Y.Z format)
- `description` (required): Brief description of functionality
- `main_file` (required): Python file containing the Plugin class
- `author` (optional): Plugin author name
- `email` (optional): Contact email
- `website` (optional): Plugin homepage or documentation
- `requires` (optional): List of required Python packages
- `permissions` (optional): List of requested permissions
- `min_app_version` (optional): Minimum app version required
- `max_app_version` (optional): Maximum app version supported

#### 3. Main Plugin File (`plugin.py`)
Must contain a class named `Plugin` that inherits from `PluginBase`.

### Optional Files

#### Configuration File (`config.json`)
Store plugin-specific settings:
```json
{
  "api_key": "",
  "refresh_interval": 300,
  "enabled_features": ["notifications", "email_sync"]
}
```

#### Package Initialization (`__init__.py`)
Makes the plugin directory a Python package:
```python
"""
Your Plugin Name

A comprehensive plugin for extending Focus Utility functionality.
"""

__version__ = "1.0.0"
__author__ = "Your Name"
```

---

## API Reference

### PluginBase Class

All plugins must inherit from `PluginBase` and implement required abstract methods.

```python
from abc import ABC, abstractmethod
from typing import Dict, List, Any

class PluginBase(ABC):
    def __init__(self):
        self.name = "Unknown Plugin"
        self.version = "1.0.0"
        self.description = "A focus utility plugin"
        self.enabled = False
```

#### Required Methods

##### `initialize() -> bool`
Called when the plugin is loaded and enabled.
```python
@abstractmethod
def initialize(self) -> bool:
    """
    Initialize the plugin.
    
    Returns:
        bool: True if initialization successful, False otherwise
        
    Example:
        def initialize(self) -> bool:
            try:
                self.load_config()
                self.setup_connections()
                return True
            except Exception as e:
                print(f"Initialization failed: {e}")
                return False
    """
    pass
```

##### `cleanup()`
Called when the plugin is disabled or the application closes.
```python
@abstractmethod
def cleanup(self):
    """
    Cleanup resources when plugin is disabled.
    
    Example:
        def cleanup(self):
            if hasattr(self, 'timer'):
                self.timer.stop()
            if hasattr(self, 'network_session'):
                self.network_session.close()
    """
    pass
```

#### Optional Hook Methods

##### `on_goals_analyzed(goals, goals_text) -> List[str]`
Called after AI analyzes user goals. Plugin can modify the goals list.
```python
def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
    """
    Process goals after AI analysis.
    
    Args:
        goals: List of goal strings from AI analysis
        goals_text: Original goals text entered by user
        
    Returns:
        List[str]: Modified goals list (can add, remove, or modify goals)
        
    Example:
        def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
            # Add tasks from external service
            external_tasks = self.fetch_urgent_tasks()
            
            enhanced_goals = goals.copy()
            for task in external_tasks:
                enhanced_goals.append(f"• {task}")
            
            return enhanced_goals
    """
    return goals
```

##### `on_session_start(session_data)`
Called when a focus session begins.
```python
def on_session_start(self, session_data: Dict[str, Any]):
    """
    Handle session start event.
    
    Args:
        session_data: Dictionary containing session information
            - mode: str - Focus mode (productivity/creativity/social)
            - duration_minutes: int - Session duration
            - goals: List[str] - Final goals list
            - start_time: datetime - Session start time
            
    Example:
        def on_session_start(self, session_data: Dict[str, Any]):
            mode = session_data.get('mode', 'unknown')
            duration = session_data.get('duration_minutes', 0)
            
            # Log session start
            self.log_session_event('start', mode, duration)
            
            # Send notification to external service
            self.notify_external_service('session_started', session_data)
    """
    pass
```

##### `on_session_update(elapsed_minutes, progress_percent)`
Called periodically during the session (typically every minute).
```python
def on_session_update(self, elapsed_minutes: float, progress_percent: float):
    """
    Handle periodic session updates.
    
    Args:
        elapsed_minutes: Minutes elapsed since session start
        progress_percent: Completion percentage (0.0 to 100.0)
        
    Example:
        def on_session_update(self, elapsed_minutes: float, progress_percent: float):
            # Send progress to external dashboard
            if elapsed_minutes % 5 == 0:  # Every 5 minutes
                self.update_external_dashboard(elapsed_minutes, progress_percent)
            
            # Check for important notifications
            if self.has_urgent_notifications():
                self.show_notification("Urgent Task", "You have a new high-priority task")
    """
    pass
```

##### `on_session_end(session_data)`
Called when the session completes.
```python
def on_session_end(self, session_data: Dict[str, Any]):
    """
    Handle session completion.
    
    Args:
        session_data: Dictionary containing session results
            - mode: str - Focus mode used
            - duration_minutes: int - Planned duration
            - elapsed_minutes: float - Actual time elapsed
            - goals: List[str] - Session goals
            - completed_goals: List[str] - Goals marked as completed
            - end_time: datetime - Session end time
            
    Example:
        def on_session_end(self, session_data: Dict[str, Any]):
            elapsed = session_data.get('elapsed_minutes', 0)
            completed = len(session_data.get('completed_goals', []))
            total = len(session_data.get('goals', []))
            
            # Log session statistics
            self.log_session_stats(elapsed, completed, total)
            
            # Update external productivity tracker
            self.sync_session_results(session_data)
    """
    pass
```

##### `on_checklist_item_changed(item_text, is_checked)`
**NEW:** Called when a checklist item is checked or unchecked during the session.
```python
def on_checklist_item_changed(self, item_text: str, is_checked: bool):
    """
    Handle checklist item state changes.
    
    Args:
        item_text: The text of the checklist item that changed
        is_checked: Boolean indicating if the item is now checked
        
    Example:
        def on_checklist_item_changed(self, item_text: str, is_checked: bool):
            if is_checked:
                print(f"✅ Completed: {item_text}")
                # Could trigger celebration, update external tracking, etc.
                self.celebrate_completion(item_text)
            else:
                print(f"↩️ Unchecked: {item_text}")
                # Handle unchecking if needed
    """
    pass
```

### Checklist API Methods

**NEW:** These methods allow plugins to interact with the progress checklist during sessions:

#### `get_checklist_progress_percentage() -> float`
Get the current checklist completion percentage.
```python
def on_session_update(self, elapsed_minutes: float, progress_percent: float):
    # Get checklist-specific progress (different from time progress)
    checklist_progress = self.get_checklist_progress_percentage()
    
    if checklist_progress >= 50.0:
        print(f"Great progress! {checklist_progress:.1f}% of tasks completed")
    
    # Update external dashboard
    self.update_dashboard(time_progress=progress_percent, task_progress=checklist_progress)
```

#### `get_completed_checklist_items() -> List[str]`
Get list of completed checklist items.
```python
def calculate_productivity_score(self):
    completed_items = self.get_completed_checklist_items()
    all_items = self.get_all_checklist_items()
    
    # Calculate weighted score based on task complexity
    score = 0
    for item in completed_items:
        if "urgent" in item.lower():
            score += 3
        elif "important" in item.lower():
            score += 2
        else:
            score += 1
    
    return score
```

#### `get_all_checklist_items() -> List[str]`
Get list of all checklist items.
```python
def analyze_task_distribution(self):
    all_items = self.get_all_checklist_items()
    completed_items = self.get_completed_checklist_items()
    
    # Categorize tasks
    urgent_tasks = [item for item in all_items if "urgent" in item.lower()]
    routine_tasks = [item for item in all_items if item not in urgent_tasks]
    
    print(f"Task Analysis:")
    print(f"  Total: {len(all_items)}")
    print(f"  Completed: {len(completed_items)}")
    print(f"  Urgent: {len(urgent_tasks)}")
    print(f"  Routine: {len(routine_tasks)}")
```

#### `set_checklist_item_checked(item_text: str, checked: bool) -> bool`
Programmatically check/uncheck a checklist item.
```python
def auto_complete_routine_tasks(self):
    all_items = self.get_all_checklist_items()
    
    # Auto-complete certain routine tasks
    for item in all_items:
        if "backup files" in item.lower():
            if self.perform_backup():
                # Mark as completed
                success = self.set_checklist_item_checked(item, True)
                if success:
                    print(f"✅ Auto-completed: {item}")
        elif "check email" in item.lower():
            if self.quick_email_check():
                self.set_checklist_item_checked(item, True)
```

---

## Hook System

### Understanding Hooks

Hooks are predefined points in the application lifecycle where plugins can inject custom functionality. The main application broadcasts events to all enabled plugins.

### Hook Execution Order

1. **Discovery Phase**: Plugins are loaded and initialized
2. **Goal Analysis Phase**: `on_goals_analyzed` hooks are called
3. **Session Start Phase**: `on_session_start` hooks are called
4. **Session Active Phase**: `on_session_update` hooks are called periodically
5. **Session End Phase**: `on_session_end` hooks are called
6. **Cleanup Phase**: `cleanup` methods are called

### Hook Best Practices

#### 1. Fail Gracefully
```python
def on_session_start(self, session_data: Dict[str, Any]):
    try:
        # Your plugin functionality
        self.process_session_start(session_data)
    except Exception as e:
        # Log error but don't crash
        print(f"Plugin error in session start: {e}")
        # Continue execution - don't re-raise
```

#### 2. Return Quickly
```python
def on_session_update(self, elapsed_minutes: float, progress_percent: float):
    # Avoid blocking operations in hooks
    if self.should_update(elapsed_minutes):
        # Use threading for long operations
        import threading
        threading.Thread(target=self.async_update, daemon=True).start()
```

#### 3. Validate Input Data
```python
def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
    # Always validate inputs
    if not isinstance(goals, list):
        print("Warning: Invalid goals data received")
        return []
    
    # Validate goal format
    valid_goals = []
    for goal in goals:
        if isinstance(goal, str) and goal.strip():
            valid_goals.append(goal)
    
    return self.enhance_goals(valid_goals)
```

### Custom Signals (Advanced)

For advanced plugins, you can emit custom signals to communicate with the main application:

```python
from PyQt5.QtCore import QObject, pyqtSignal

class AdvancedPlugin(PluginBase, QObject):
    # Define custom signals
    task_completed = pyqtSignal(str)  # Task ID
    notification_requested = pyqtSignal(str, str)  # Title, Message
    
    def __init__(self):
        PluginBase.__init__(self)
        QObject.__init__(self)
    
    def complete_task(self, task_id: str):
        # Emit signal when task is completed
        self.task_completed.emit(task_id)
    
    def request_notification(self, title: str, message: str):
        # Request main app to show notification
        self.notification_requested.emit(title, message)
```

---

## Configuration Management

### Plugin Configuration

Most plugins need to store configuration data. Here's how to handle it properly:

#### 1. Configuration File Structure
Create a `config.json` file in your plugin directory:
```json
{
  "api_settings": {
    "base_url": "https://api.example.com",
    "api_key": "",
    "timeout": 30
  },
  "user_preferences": {
    "notification_frequency": "medium",
    "auto_sync": true,
    "debug_mode": false
  },
  "feature_flags": {
    "experimental_features": false,
    "beta_ui": false
  }
}
```

#### 2. Configuration Loading
```python
import json
import os
from typing import Dict, Any

class ConfigurablePlugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.config = {}
        self.config_file = os.path.join(os.path.dirname(__file__), 'config.json')
    
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file with defaults"""
        default_config = {
            "api_settings": {
                "base_url": "https://api.example.com",
                "api_key": "",
                "timeout": 30
            },
            "user_preferences": {
                "notification_frequency": "medium",
                "auto_sync": True,
                "debug_mode": False
            }
        }
        
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    loaded_config = json.load(f)
                
                # Merge with defaults
                self.config = self.merge_configs(default_config, loaded_config)
            else:
                self.config = default_config
                self.save_config()  # Create default config file
                
        except json.JSONDecodeError as e:
            print(f"Invalid config file: {e}")
            self.config = default_config
        except Exception as e:
            print(f"Error loading config: {e}")
            self.config = default_config
        
        return self.config
    
    def save_config(self):
        """Save current configuration to file"""
        try:
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
        except Exception as e:
            print(f"Error saving config: {e}")
    
    def merge_configs(self, default: Dict, loaded: Dict) -> Dict:
        """Merge loaded config with defaults"""
        result = default.copy()
        
        for key, value in loaded.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self.merge_configs(result[key], value)
            else:
                result[key] = value
        
        return result
    
    def get_config_value(self, key_path: str, default=None):
        """Get configuration value using dot notation"""
        keys = key_path.split('.')
        value = self.config
        
        try:
            for key in keys:
                value = value[key]
            return value
        except (KeyError, TypeError):
            return default
    
    def set_config_value(self, key_path: str, value):
        """Set configuration value using dot notation"""
        keys = key_path.split('.')
        config = self.config
        
        # Navigate to parent
        for key in keys[:-1]:
            if key not in config:
                config[key] = {}
            config = config[key]
        
        # Set final value
        config[keys[-1]] = value
        self.save_config()
```

#### 3. Using Configuration
```python
def initialize(self) -> bool:
    self.load_config()
    
    # Use configuration values
    self.api_key = self.get_config_value('api_settings.api_key')
    self.debug_mode = self.get_config_value('user_preferences.debug_mode', False)
    
    if not self.api_key:
        print("Warning: No API key configured")
        return False
    
    return True

def update_setting(self, setting: str, value):
    """Update a configuration setting"""
    self.set_config_value(setting, value)
    print(f"Updated {setting} to {value}")
```

### Environment Variables

For sensitive data like API keys, consider using environment variables:

```python
import os

class SecurePlugin(PluginBase):
    def initialize(self) -> bool:
        # Try environment variable first, then config file
        self.api_key = (
            os.getenv('PLUGIN_API_KEY') or 
            self.get_config_value('api_settings.api_key')
        )
        
        if not self.api_key:
            print("Error: No API key found in environment or config")
            return False
        
        return True
```

---

## UI Integration

### Configuration Dialogs

Many plugins need custom configuration interfaces. Here's how to create them:

#### 1. Basic Configuration Dialog
```python
from PyQt5.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel, 
                             QPushButton, QLineEdit, QCheckBox, QComboBox)
from PyQt5.QtCore import Qt

class PluginConfigDialog(QDialog):
    def __init__(self, plugin_instance, parent=None):
        super().__init__(parent)
        self.plugin = plugin_instance
        self.init_ui()
    
    def init_ui(self):
        self.setWindowTitle(f'{self.plugin.name} Configuration')
        self.setFixedSize(500, 400)
        
        # Ensure window comes to front
        self.activateWindow()
        self.raise_()
        
        layout = QVBoxLayout()
        layout.setSpacing(15)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Title
        title = QLabel(f"Configure {self.plugin.name}")
        title.setStyleSheet("font-size: 16px; font-weight: bold;")
        layout.addWidget(title)
        
        # API Key field
        api_layout = QHBoxLayout()
        api_layout.addWidget(QLabel("API Key:"))
        self.api_key_input = QLineEdit()
        self.api_key_input.setEchoMode(QLineEdit.Password)
        self.api_key_input.setText(self.plugin.get_config_value('api_settings.api_key', ''))
        api_layout.addWidget(self.api_key_input)
        layout.addLayout(api_layout)
        
        # Auto-sync checkbox
        self.auto_sync_check = QCheckBox("Enable automatic synchronization")
        self.auto_sync_check.setChecked(
            self.plugin.get_config_value('user_preferences.auto_sync', True)
        )
        layout.addWidget(self.auto_sync_check)
        
        # Notification frequency
        freq_layout = QHBoxLayout()
        freq_layout.addWidget(QLabel("Notification Frequency:"))
        self.freq_combo = QComboBox()
        self.freq_combo.addItems(["low", "medium", "high"])
        current_freq = self.plugin.get_config_value('user_preferences.notification_frequency', 'medium')
        self.freq_combo.setCurrentText(current_freq)
        freq_layout.addWidget(self.freq_combo)
        layout.addLayout(freq_layout)
        
        # Buttons
        button_layout = QHBoxLayout()
        
        test_btn = QPushButton("Test Connection")
        test_btn.clicked.connect(self.test_connection)
        
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        
        save_btn = QPushButton("Save")
        save_btn.clicked.connect(self.save_config)
        save_btn.setDefault(True)
        
        button_layout.addWidget(test_btn)
        button_layout.addStretch()
        button_layout.addWidget(cancel_btn)
        button_layout.addWidget(save_btn)
        
        layout.addLayout(button_layout)
        self.setLayout(layout)
    
    def test_connection(self):
        """Test the API connection with current settings"""
        api_key = self.api_key_input.text().strip()
        
        if not api_key:
            self.show_message("Error", "Please enter an API key")
            return
        
        try:
            # Test connection using temporary settings
            success = self.plugin.test_api_connection(api_key)
            
            if success:
                self.show_message("Success", "Connection test successful!")
            else:
                self.show_message("Error", "Connection test failed")
                
        except Exception as e:
            self.show_message("Error", f"Connection test failed: {e}")
    
    def save_config(self):
        """Save configuration and close dialog"""
        try:
            # Update plugin configuration
            self.plugin.set_config_value('api_settings.api_key', self.api_key_input.text().strip())
            self.plugin.set_config_value('user_preferences.auto_sync', self.auto_sync_check.isChecked())
            self.plugin.set_config_value('user_preferences.notification_frequency', self.freq_combo.currentText())
            
            self.show_message("Success", "Configuration saved successfully!")
            self.accept()
            
        except Exception as e:
            self.show_message("Error", f"Failed to save configuration: {e}")
    
    def show_message(self, title: str, message: str):
        """Show a message dialog"""
        from PyQt5.QtWidgets import QMessageBox
        
        msg_box = QMessageBox(self)
        msg_box.setWindowTitle(title)
        msg_box.setText(message)
        msg_box.exec_()
```

#### 2. Integrating with Plugin Settings Dialog

To show your configuration dialog from the main plugin settings, add a `configure` method:

```python
class MyPlugin(PluginBase):
    def configure(self):
        """Show plugin configuration dialog"""
        dialog = PluginConfigDialog(self)
        dialog.exec_()
```

The main application will automatically detect this method and show a "Configure" button for your plugin.

#### 3. Status Display

You can also provide status information that appears in the plugin settings:

```python
class MyPlugin(PluginBase):
    def get_status_text(self) -> str:
        """Return status text for plugin settings display"""
        if not self.get_config_value('api_settings.api_key'):
            return "⚠ Not configured - click Configure to set up"
        
        if self.is_connected():
            return f"✓ Connected to {self.get_service_name()}"
        else:
            return "✗ Connection failed - check configuration"
    
    def is_connected(self) -> bool:
        """Check if plugin is properly connected to external service"""
        try:
            return self.test_api_connection(self.get_config_value('api_settings.api_key'))
        except:
            return False
```

---

## Testing and Debugging

### Local Testing

#### 1. Plugin Test Runner
Create a test script for your plugin:

```python
#!/usr/bin/env python3
"""
Test runner for your plugin - allows testing without full application
"""

import sys
import os

# Add paths for imports
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
sys.path.append(os.path.dirname(__file__))

from plugin import Plugin

def test_plugin():
    """Test basic plugin functionality"""
    print("Testing plugin...")
    
    # Create plugin instance
    plugin = Plugin()
    
    # Test initialization
    print("Testing initialization...")
    success = plugin.initialize()
    print(f"Initialization: {'✓ PASSED' if success else '✗ FAILED'}")
    
    # Test hook methods
    print("\nTesting hooks...")
    
    # Test goals analysis
    test_goals = ["• Complete project", "• Review documents"]
    result_goals = plugin.on_goals_analyzed(test_goals, "Complete project\nReview documents")
    print(f"Goals analysis: {'✓ PASSED' if isinstance(result_goals, list) else '✗ FAILED'}")
    print(f"  Input goals: {len(test_goals)}")
    print(f"  Output goals: {len(result_goals)}")
    
    # Test session start
    session_data = {
        'mode': 'productivity',
        'duration_minutes': 30,
        'goals': result_goals
    }
    
    try:
        plugin.on_session_start(session_data)
        print("Session start: ✓ PASSED")
    except Exception as e:
        print(f"Session start: ✗ FAILED - {e}")
    
    # Test session update
    try:
        plugin.on_session_update(5.0, 16.7)  # 5 minutes, 16.7% complete
        print("Session update: ✓ PASSED")
    except Exception as e:
        print(f"Session update: ✗ FAILED - {e}")
    
    # Test session end
    end_data = session_data.copy()
    end_data['elapsed_minutes'] = 25.5
    end_data['completed_goals'] = result_goals[:1]  # First goal completed
    
    try:
        plugin.on_session_end(end_data)
        print("Session end: ✓ PASSED")
    except Exception as e:
        print(f"Session end: ✗ FAILED - {e}")
    
    # Test cleanup
    try:
        plugin.cleanup()
        print("Cleanup: ✓ PASSED")
    except Exception as e:
        print(f"Cleanup: ✗ FAILED - {e}")
    
    print("\nPlugin testing completed!")

if __name__ == "__main__":
    test_plugin()
```

#### 2. Configuration Testing
Test your configuration system:

```python
def test_configuration():
    """Test plugin configuration system"""
    plugin = Plugin()
    
    # Test loading default config
    config = plugin.load_config()
    assert isinstance(config, dict), "Config should be a dictionary"
    
    # Test setting values
    plugin.set_config_value('test.nested.value', 42)
    assert plugin.get_config_value('test.nested.value') == 42
    
    # Test saving and loading
    plugin.save_config()
    plugin.config = {}  # Clear memory
    plugin.load_config()
    assert plugin.get_config_value('test.nested.value') == 42
    
    print("Configuration testing: ✓ PASSED")
```

### Debugging

#### 1. Logging
Add comprehensive logging to your plugin:

```python
import logging
import os

class DebuggablePlugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.setup_logging()
    
    def setup_logging(self):
        """Setup plugin-specific logging"""
        self.logger = logging.getLogger(f'focus_utility.plugin.{self.name.lower().replace(" ", "_")}')
        
        # Only add handler if not already added
        if not self.logger.handlers:
            # File handler
            log_file = os.path.join(os.path.dirname(__file__), f'{self.name.lower()}.log')
            file_handler = logging.FileHandler(log_file)
            file_handler.setLevel(logging.DEBUG)
            
            # Console handler
            console_handler = logging.StreamHandler()
            console_handler.setLevel(logging.INFO)
            
            # Formatter
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            file_handler.setFormatter(formatter)
            console_handler.setFormatter(formatter)
            
            self.logger.addHandler(file_handler)
            self.logger.addHandler(console_handler)
            self.logger.setLevel(logging.DEBUG)
    
    def initialize(self) -> bool:
        self.logger.info("Plugin initialization starting")
        
        try:
            self.load_config()
            self.logger.debug(f"Config loaded: {self.config}")
            
            # Your initialization code here
            
            self.logger.info("Plugin initialization completed successfully")
            return True
            
        except Exception as e:
            self.logger.error(f"Plugin initialization failed: {e}", exc_info=True)
            return False
    
    def on_session_start(self, session_data):
        self.logger.info(f"Session started: {session_data.get('mode')} mode, {session_data.get('duration_minutes')} minutes")
        self.logger.debug(f"Full session data: {session_data}")
```

#### 2. Error Handling
Implement robust error handling:

```python
def safe_hook_execution(func):
    """Decorator for safe hook execution"""
    def wrapper(self, *args, **kwargs):
        try:
            return func(self, *args, **kwargs)
        except Exception as e:
            if hasattr(self, 'logger'):
                self.logger.error(f"Error in {func.__name__}: {e}", exc_info=True)
            else:
                print(f"Plugin error in {func.__name__}: {e}")
            
            # Return safe defaults
            if func.__name__ == 'on_goals_analyzed':
                return args[0] if args else []  # Return original goals
            
    return wrapper

class SafePlugin(PluginBase):
    @safe_hook_execution
    def on_goals_analyzed(self, goals, goals_text):
        # Your implementation here
        return self.process_goals(goals, goals_text)
    
    @safe_hook_execution
    def on_session_start(self, session_data):
        # Your implementation here
        self.handle_session_start(session_data)
```

---

## Best Practices

### 1. Plugin Design Principles

#### Single Responsibility
Each plugin should focus on one specific functionality:
```python
# Good: Focused email integration plugin
class EmailAssistantPlugin(PluginBase):
    """Integrates with email to suggest tasks from important messages"""
    
# Bad: Plugin that does too many things
class EverythingPlugin(PluginBase):
    """Handles email, calendar, weather, news, and social media"""
```

#### Fail Gracefully
Never let your plugin crash the main application:
```python
def on_session_start(self, session_data):
    try:
        self.complex_operation(session_data)
    except NetworkError:
        self.logger.warning("Network unavailable, using cached data")
        self.use_cached_data()
    except ConfigurationError:
        self.logger.error("Plugin not properly configured")
        self.show_config_prompt()
    except Exception as e:
        self.logger.error(f"Unexpected error: {e}")
        # Don't re-raise - just log and continue
```

#### Be Respectful of Resources
```python
class EfficientPlugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.cache = {}
        self.last_update = 0
        self.update_interval = 300  # 5 minutes
    
    def on_session_update(self, elapsed_minutes, progress_percent):
        current_time = time.time()
        
        # Don't update too frequently
        if current_time - self.last_update < self.update_interval:
            return
        
        # Use caching to avoid repeated API calls
        cache_key = f"update_{int(elapsed_minutes)}"
        if cache_key not in self.cache:
            self.cache[cache_key] = self.expensive_operation()
        
        self.last_update = current_time
```

### 2. Configuration Management

#### Use Sensible Defaults
```python
def load_config(self):
    defaults = {
        'update_interval': 300,
        'max_results': 10,
        'timeout': 30,
        'enabled_features': ['notifications'],
        'api_base_url': 'https://api.example.com/v1'
    }
    
    # Merge with user config
    user_config = self.load_user_config()
    self.config = {**defaults, **user_config}
```

#### Validate Configuration
```python
def validate_config(self) -> bool:
    """Validate plugin configuration"""
    required_fields = ['api_key', 'api_base_url']
    
    for field in required_fields:
        if not self.get_config_value(field):
            self.logger.error(f"Missing required configuration: {field}")
            return False
    
    # Validate API key format
    api_key = self.get_config_value('api_key')
    if len(api_key) < 20:
        self.logger.error("API key appears to be invalid (too short)")
        return False
    
    return True
```

### 3. User Experience

#### Provide Clear Feedback
```python
def on_goals_analyzed(self, goals, goals_text):
    if not self.is_configured():
        # Don't silently fail - let user know
        goals.append("• Configure your plugin to get personalized suggestions")
        return goals
    
    try:
        enhanced_goals = self.enhance_goals(goals)
        
        # Let user know what was added
        added_count = len(enhanced_goals) - len(goals)
        if added_count > 0:
            print(f"Added {added_count} tasks from your external service")
        
        return enhanced_goals
        
    except Exception as e:
        self.logger.error(f"Failed to enhance goals: {e}")
        goals.append("• Check plugin configuration - enhancement failed")
        return goals
```

#### Be Informative but Not Annoying
```python
def show_notification(self, title, message, importance='normal'):
    """Show notification with appropriate frequency"""
    
    # Don't spam notifications
    if importance == 'low' and not self.should_show_low_importance():
        return
    
    # Track notification frequency
    self.notification_count += 1
    
    # Show the notification
    self.emit_notification(title, message)

def should_show_low_importance(self) -> bool:
    """Determine if low-importance notifications should be shown"""
    freq = self.get_config_value('notification_frequency', 'medium')
    
    if freq == 'high':
        return True
    elif freq == 'low':
        return self.notification_count < 2  # Max 2 per session
    else:  # medium
        return self.notification_count < 5  # Max 5 per session
```

### 4. Security Considerations

#### Secure API Key Storage
```python
import keyring
from cryptography.fernet import Fernet

class SecurePlugin(PluginBase):
    def store_api_key(self, api_key: str):
        """Store API key securely using system keychain"""
        try:
            keyring.set_password("focus_utility", f"{self.name}_api_key", api_key)
        except Exception as e:
            self.logger.warning(f"Could not store API key securely: {e}")
            # Fallback to encrypted config file
            self.store_encrypted_key(api_key)
    
    def get_api_key(self) -> str:
        """Retrieve API key securely"""
        try:
            return keyring.get_password("focus_utility", f"{self.name}_api_key")
        except Exception as e:
            self.logger.warning(f"Could not retrieve API key from keychain: {e}")
            return self.get_encrypted_key()
```

#### Input Validation
```python
def process_user_input(self, user_input: str) -> str:
    """Process user input safely"""
    # Sanitize input
    sanitized = user_input.strip()
    
    # Validate length
    if len(sanitized) > 1000:
        raise ValueError("Input too long")
    
    # Remove potentially dangerous characters
    dangerous_chars = ['<', '>', '&', '"', "'", '`']
    for char in dangerous_chars:
        sanitized = sanitized.replace(char, '')
    
    return sanitized
```

---

## Advanced Topics

### 1. Asynchronous Operations

For plugins that need to perform network requests or other long-running operations:

```python
import asyncio
import aiohttp
from concurrent.futures import ThreadPoolExecutor
from PyQt5.QtCore import QTimer

class AsyncPlugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.executor = ThreadPoolExecutor(max_workers=2)
        self.session = None
    
    def initialize(self) -> bool:
        # Setup async HTTP session
        self.setup_async_session()
        return True
    
    def setup_async_session(self):
        """Setup aiohttp session for async requests"""
        connector = aiohttp.TCPConnector(limit=10)
        timeout = aiohttp.ClientTimeout(total=30)
        self.session = aiohttp.ClientSession(
            connector=connector,
            timeout=timeout
        )
    
    def on_session_start(self, session_data):
        # Start async task without blocking
        self.start_background_task(session_data)
    
    def start_background_task(self, session_data):
        """Start long-running task in background"""
        def run_async():
            try:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                loop.run_until_complete(self.async_session_handler(session_data))
            except Exception as e:
                self.logger.error(f"Async task failed: {e}")
            finally:
                loop.close()
        
        # Run in thread pool to avoid blocking
        self.executor.submit(run_async)
    
    async def async_session_handler(self, session_data):
        """Handle session start asynchronously"""
        try:
            # Make async API call
            data = await self.fetch_external_data(session_data)
            
            # Process results
            tasks = self.process_external_data(data)
            
            # Update UI on main thread
            QTimer.singleShot(0, lambda: self.update_ui_with_tasks(tasks))
            
        except Exception as e:
            self.logger.error(f"Async handler error: {e}")
    
    async def fetch_external_data(self, session_data):
        """Fetch data from external API"""
        url = f"{self.api_base_url}/sessions"
        headers = {'Authorization': f'Bearer {self.api_key}'}
        
        async with self.session.post(url, json=session_data, headers=headers) as response:
            if response.status == 200:
                return await response.json()
            else:
                raise Exception(f"API error: {response.status}")
    
    def cleanup(self):
        # Close async session
        if self.session:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            loop.run_until_complete(self.session.close())
            loop.close()
        
        # Shutdown thread pool
        self.executor.shutdown(wait=True)
```

### 2. Database Integration

For plugins that need to store persistent data:

```python
import sqlite3
import os
from contextlib import contextmanager
from typing import List, Dict, Any

class DatabasePlugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.db_path = os.path.join(os.path.dirname(__file__), 'plugin_data.db')
        self.init_database()
    
    def init_database(self):
        """Initialize SQLite database"""
        with self.get_db_connection() as conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    mode TEXT,
                    duration_minutes INTEGER,
                    goals_count INTEGER,
                    completed_count INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            conn.execute('''
                CREATE TABLE IF NOT EXISTS goals (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id INTEGER,
                    goal_text TEXT,
                    completed BOOLEAN DEFAULT FALSE,
                    priority INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (session_id) REFERENCES sessions (id)
                )
            ''')
    
    @contextmanager
    def get_db_connection(self):
        """Get database connection with automatic cleanup"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row  # Enable dict-like access
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
    
    def on_session_start(self, session_data):
        """Store session start in database"""
        with self.get_db_connection() as conn:
            cursor = conn.execute('''
                INSERT INTO sessions (start_time, mode, duration_minutes, goals_count)
                VALUES (datetime('now'), ?, ?, ?)
            ''', (
                session_data.get('mode'),
                session_data.get('duration_minutes'),
                len(session_data.get('goals', []))
            ))
            
            session_id = cursor.lastrowid
            
            # Store individual goals
            for i, goal in enumerate(session_data.get('goals', [])):
                conn.execute('''
                    INSERT INTO goals (session_id, goal_text, priority)
                    VALUES (?, ?, ?)
                ''', (session_id, goal, i))
            
            # Store session ID for later use
            self.current_session_id = session_id
    
    def on_session_end(self, session_data):
        """Update session completion in database"""
        if not hasattr(self, 'current_session_id'):
            return
        
        with self.get_db_connection() as conn:
            # Update session record
            conn.execute('''
                UPDATE sessions 
                SET end_time = datetime('now'), completed_count = ?
                WHERE id = ?
            ''', (
                len(session_data.get('completed_goals', [])),
                self.current_session_id
            ))
            
            # Mark completed goals
            for goal in session_data.get('completed_goals', []):
                conn.execute('''
                    UPDATE goals 
                    SET completed = TRUE 
                    WHERE session_id = ? AND goal_text = ?
                ''', (self.current_session_id, goal))
    
    def get_session_history(self, limit: int = 10) -> List[Dict]:
        """Get recent session history"""
        with self.get_db_connection() as conn:
            cursor = conn.execute('''
                SELECT * FROM sessions 
                ORDER BY start_time DESC 
                LIMIT ?
            ''', (limit,))
            
            return [dict(row) for row in cursor.fetchall()]
    
    def get_productivity_stats(self) -> Dict[str, Any]:
        """Get productivity statistics"""
        with self.get_db_connection() as conn:
            # Total sessions
            total_sessions = conn.execute('SELECT COUNT(*) FROM sessions').fetchone()[0]
            
            # Average completion rate
            avg_completion = conn.execute('''
                SELECT AVG(CAST(completed_count AS FLOAT) / goals_count) 
                FROM sessions 
                WHERE goals_count > 0
            ''').fetchone()[0] or 0
            
            # Most productive mode
            productive_mode = conn.execute('''
                SELECT mode, AVG(CAST(completed_count AS FLOAT) / goals_count) as avg_rate
                FROM sessions 
                WHERE goals_count > 0
                GROUP BY mode
                ORDER BY avg_rate DESC
                LIMIT 1
            ''').fetchone()
            
            return {
                'total_sessions': total_sessions,
                'average_completion_rate': avg_completion,
                'most_productive_mode': dict(productive_mode) if productive_mode else None
            }
```

### 3. Custom Notifications

Create rich notifications with custom styling:

```python
from PyQt5.QtWidgets import QWidget, QLabel, QVBoxLayout, QHBoxLayout
from PyQt5.QtCore import QTimer, QPropertyAnimation, QRect
from PyQt5.QtGui import QPixmap, QPainter, QPen, QBrush

class CustomNotificationWidget(QWidget):
    def __init__(self, title: str, message: str, duration: int = 5000):
        super().__init__()
        self.title = title
        self.message = message
        self.duration = duration
        self.init_ui()
        self.setup_animation()
    
    def init_ui(self):
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setFixedSize(350, 100)
        
        # Position in top-right corner
        screen = QApplication.desktop().screenGeometry()
        self.move(screen.width() - 370, 20)
        
        # Create layout
        layout = QVBoxLayout()
        layout.setContentsMargins(15, 10, 15, 10)
        
        # Title
        title_label = QLabel(self.title)
        title_label.setStyleSheet("""
            font-size: 14px;
            font-weight: bold;
            color: #1d1d1f;
        """)
        
        # Message
        message_label = QLabel(self.message)
        message_label.setWordWrap(True)
        message_label.setStyleSheet("""
            font-size: 12px;
            color: #4a4a4a;
        """)
        
        layout.addWidget(title_label)
        layout.addWidget(message_label)
        self.setLayout(layout)
        
        # Styling
        self.setStyleSheet("""
            QWidget {
                background-color: rgba(255, 255, 255, 240);
                border: 1px solid #d1d1d6;
                border-radius: 10px;
            }
        """)
    
    def setup_animation(self):
        # Slide in animation
        self.slide_animation = QPropertyAnimation(self, b"geometry")
        self.slide_animation.setDuration(300)
        
        start_rect = QRect(self.x() + 370, self.y(), self.width(), self.height())
        end_rect = QRect(self.x(), self.y(), self.width(), self.height())
        
        self.slide_animation.setStartValue(start_rect)
        self.slide_animation.setEndValue(end_rect)
        
        # Auto-hide timer
        self.hide_timer = QTimer()
        self.hide_timer.timeout.connect(self.hide_notification)
        self.hide_timer.setSingleShot(True)
    
    def show_notification(self):
        self.show()
        self.slide_animation.start()
        self.hide_timer.start(self.duration)
    
    def hide_notification(self):
        # Slide out animation
        slide_out = QPropertyAnimation(self, b"geometry")
        slide_out.setDuration(300)
        
        current_rect = self.geometry()
        end_rect = QRect(current_rect.x() + 370, current_rect.y(), 
                        current_rect.width(), current_rect.height())
        
        slide_out.setStartValue(current_rect)
        slide_out.setEndValue(end_rect)
        slide_out.finished.connect(self.close)
        slide_out.start()

class NotificationPlugin(PluginBase):
    def show_custom_notification(self, title: str, message: str):
        """Show custom styled notification"""
        notification = CustomNotificationWidget(title, message)
        notification.show_notification()
```

---

## Example Plugins

### 1. Simple Task Manager Integration

```python
#!/usr/bin/env python3
"""
Task Manager Plugin - Integrates with external task management service
"""

import requests
import json
from typing import List, Dict, Any
from plugin_system import PluginBase

class Plugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.name = "Task Manager Integration"
        self.version = "1.0.0"
        self.description = "Sync tasks with external task management service"
        self.api_key = ""
        self.base_url = "https://api.taskmanager.com/v1"
    
    def initialize(self) -> bool:
        self.load_config()
        self.api_key = self.get_config_value('api_key', '')
        
        if not self.api_key:
            print("Task Manager: No API key configured")
            return False
        
        return self.test_connection()
    
    def test_connection(self) -> bool:
        """Test API connection"""
        try:
            response = requests.get(
                f"{self.base_url}/user",
                headers={'Authorization': f'Bearer {self.api_key}'},
                timeout=10
            )
            return response.status_code == 200
        except:
            return False
    
    def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
        """Add urgent tasks from task manager"""
        try:
            urgent_tasks = self.fetch_urgent_tasks()
            
            enhanced_goals = goals.copy()
            for task in urgent_tasks:
                enhanced_goals.append(f"• {task['title']} (Due: {task['due_date']})")
            
            if urgent_tasks:
                print(f"Added {len(urgent_tasks)} urgent tasks from task manager")
            
            return enhanced_goals
            
        except Exception as e:
            print(f"Task Manager error: {e}")
            return goals
    
    def fetch_urgent_tasks(self) -> List[Dict]:
        """Fetch urgent tasks from API"""
        response = requests.get(
            f"{self.base_url}/tasks",
            headers={'Authorization': f'Bearer {self.api_key}'},
            params={'urgent': 'true', 'limit': 5},
            timeout=10
        )
        
        if response.status_code == 200:
            return response.json().get('tasks', [])
        else:
            raise Exception(f"API error: {response.status_code}")
    
    def on_session_end(self, session_data: Dict[str, Any]):
        """Mark completed tasks in external system"""
        try:
            completed_goals = session_data.get('completed_goals', [])
            
            for goal in completed_goals:
                # Extract task ID if present
                if 'Due:' in goal:  # Tasks we added
                    self.mark_task_completed(goal)
            
        except Exception as e:
            print(f"Error updating task manager: {e}")
    
    def cleanup(self):
        """Cleanup resources"""
        pass
```

### 2. Weather-Based Focus Mode

```python
#!/usr/bin/env python3
"""
Weather Focus Plugin - Adjusts focus suggestions based on weather
"""

import requests
from datetime import datetime
from typing import List, Dict, Any
from plugin_system import PluginBase

class Plugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.name = "Weather Focus"
        self.version = "1.0.0"
        self.description = "Suggests activities based on current weather"
        self.weather_api_key = ""
        self.location = ""
    
    def initialize(self) -> bool:
        self.load_config()
        self.weather_api_key = self.get_config_value('weather_api_key', '')
        self.location = self.get_config_value('location', 'New York')
        
        return bool(self.weather_api_key)
    
    def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
        """Add weather-appropriate suggestions"""
        try:
            weather = self.get_current_weather()
            suggestions = self.get_weather_suggestions(weather)
            
            enhanced_goals = goals.copy()
            for suggestion in suggestions:
                enhanced_goals.append(f"• {suggestion} (Weather: {weather['condition']})")
            
            return enhanced_goals
            
        except Exception as e:
            print(f"Weather plugin error: {e}")
            return goals
    
    def get_current_weather(self) -> Dict:
        """Fetch current weather data"""
        url = f"http://api.openweathermap.org/data/2.5/weather"
        params = {
            'q': self.location,
            'appid': self.weather_api_key,
            'units': 'metric'
        }
        
        response = requests.get(url, params=params, timeout=10)
        data = response.json()
        
        return {
            'temperature': data['main']['temp'],
            'condition': data['weather'][0]['main'].lower(),
            'description': data['weather'][0]['description']
        }
    
    def get_weather_suggestions(self, weather: Dict) -> List[str]:
        """Generate weather-appropriate suggestions"""
        temp = weather['temperature']
        condition = weather['condition']
        
        suggestions = []
        
        if condition == 'rain':
            suggestions.extend([
                "Perfect indoor focus time - tackle that complex project",
                "Review documents while listening to rain sounds"
            ])
        elif condition == 'clear' and temp > 20:
            suggestions.extend([
                "Take breaks outside for fresh air",
                "Consider working near a window for natural light"
            ])
        elif temp < 5:
            suggestions.extend([
                "Make a warm drink before starting",
                "Cozy indoor work session ahead"
            ])
        elif condition == 'snow':
            suggestions.extend([
                "Perfect snow day for deep focus work",
                "Enjoy the peaceful atmosphere for concentration"
            ])
        
        return suggestions[:2]  # Limit to 2 suggestions
    
    def cleanup(self):
        pass
```

### 3. Pomodoro Timer Integration

```python
#!/usr/bin/env python3
"""
Pomodoro Plugin - Breaks focus sessions into Pomodoro intervals
"""

from PyQt5.QtCore import QTimer, pyqtSignal
from typing import Dict, Any
from plugin_system import PluginBase

class Plugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.name = "Pomodoro Timer"
        self.version = "1.0.0"
        self.description = "Breaks focus sessions into Pomodoro intervals with breaks"
        
        self.pomodoro_length = 25  # minutes
        self.short_break = 5       # minutes
        self.long_break = 15       # minutes
        self.pomodoros_until_long_break = 4
        
        self.current_pomodoro = 0
        self.session_active = False
        self.pomodoro_timer = QTimer()
        self.pomodoro_timer.timeout.connect(self.pomodoro_complete)
    
    def initialize(self) -> bool:
        self.load_config()
        
        # Load custom intervals if configured
        self.pomodoro_length = self.get_config_value('pomodoro_minutes', 25)
        self.short_break = self.get_config_value('short_break_minutes', 5)
        self.long_break = self.get_config_value('long_break_minutes', 15)
        
        return True
    
    def on_session_start(self, session_data: Dict[str, Any]):
        """Start Pomodoro tracking"""
        self.session_active = True
        self.current_pomodoro = 0
        
        duration = session_data.get('duration_minutes', 60)
        pomodoro_count = duration // self.pomodoro_length
        
        print(f"Pomodoro: Starting session with ~{pomodoro_count} Pomodoros")
        self.start_pomodoro()
    
    def start_pomodoro(self):
        """Start a new Pomodoro interval"""
        if not self.session_active:
            return
        
        self.current_pomodoro += 1
        print(f"Pomodoro: Starting Pomodoro #{self.current_pomodoro}")
        
        # Start timer for one Pomodoro
        self.pomodoro_timer.start(self.pomodoro_length * 60 * 1000)  # Convert to ms
    
    def pomodoro_complete(self):
        """Handle Pomodoro completion"""
        self.pomodoro_timer.stop()
        
        if not self.session_active:
            return
        
        print(f"Pomodoro: Pomodoro #{self.current_pomodoro} complete!")
        
        # Determine break length
        if self.current_pomodoro % self.pomodoros_until_long_break == 0:
            break_length = self.long_break
            break_type = "long"
        else:
            break_length = self.short_break
            break_type = "short"
        
        # Show break notification
        self.show_break_notification(break_type, break_length)
        
        # Schedule next Pomodoro after break
        QTimer.singleShot(
            break_length * 60 * 1000,  # Convert to ms
            self.start_pomodoro
        )
    
    def show_break_notification(self, break_type: str, duration: int):
        """Show break notification"""
        title = f"Pomodoro Break - {break_type.title()} Break"
        message = f"Take a {duration}-minute {break_type} break. You've earned it!"
        
        print(f"Pomodoro: {title} - {message}")
        
        # You could integrate with system notifications here
        # self.show_system_notification(title, message)
    
    def on_session_end(self, session_data: Dict[str, Any]):
        """Clean up when session ends"""
        self.session_active = False
        self.pomodoro_timer.stop()
        
        elapsed = session_data.get('elapsed_minutes', 0)
        completed_pomodoros = elapsed // self.pomodoro_length
        
        print(f"Pomodoro: Session ended. Completed ~{completed_pomodoros} Pomodoros")
    
    def cleanup(self):
        """Stop timers and cleanup"""
        self.session_active = False
        if self.pomodoro_timer.isActive():
            self.pomodoro_timer.stop()
```

---

## Troubleshooting

### Common Issues

#### 1. Plugin Not Loading

**Symptoms**: Plugin doesn't appear in the plugins list

**Possible Causes**:
- Missing or invalid `manifest.json`
- Python syntax errors in plugin file
- Missing required imports

**Solutions**:
```bash
# Check manifest syntax
python -m json.tool plugins/your_plugin/manifest.json

# Test plugin syntax
python -m py_compile plugins/your_plugin/plugin.py

# Check plugin structure
ls -la plugins/your_plugin/
```

#### 2. Import Errors

**Symptoms**: Plugin fails to initialize with import errors

**Common Issues**:
```python
# Wrong path to plugin_system
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

# Missing PyQt5 imports
from PyQt5.QtCore import QTimer

# Relative imports not working
from .config import load_settings  # Use absolute imports instead
```

**Solution**:
```python
# Correct plugin_system import
import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from plugin_system import PluginBase
```

#### 3. Hook Methods Not Called

**Symptoms**: Plugin loads but hook methods never execute

**Possible Causes**:
- Plugin not enabled in settings
- Hook method has wrong signature
- Exception in hook method

**Debug Steps**:
```python
def on_session_start(self, session_data: Dict[str, Any]):
    print(f"DEBUG: {self.name} session start called")
    print(f"DEBUG: Session data: {session_data}")
    
    try:
        # Your implementation
        self.handle_session_start(session_data)
    except Exception as e:
        print(f"DEBUG: Error in session start: {e}")
        import traceback
        traceback.print_exc()
```

#### 4. Configuration Not Saving

**Symptoms**: Settings reset every time plugin restarts

**Common Issues**:
- File permissions
- Invalid JSON in config
- Writing to wrong directory

**Debug Configuration**:
```python
def save_config(self):
    config_path = os.path.join(os.path.dirname(__file__), 'config.json')
    print(f"DEBUG: Saving config to: {config_path}")
    
    try:
        # Check if directory is writable
        if not os.access(os.path.dirname(config_path), os.W_OK):
            print("ERROR: Config directory not writable")
            return
        
        with open(config_path, 'w') as f:
            json.dump(self.config, f, indent=2)
        
        print("DEBUG: Config saved successfully")
        
    except Exception as e:
        print(f"ERROR: Failed to save config: {e}")
        import traceback
        traceback.print_exc()
```

### Debugging Tools

#### 1. Plugin Test Script
Create `test_plugin.py` in your plugin directory:

```python
#!/usr/bin/env python3
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

def test_plugin():
    try:
        from plugin import Plugin
        
        plugin = Plugin()
        print(f"Plugin: {plugin.name} v{plugin.version}")
        
        # Test initialization
        if plugin.initialize():
            print("✓ Initialization successful")
        else:
            print("✗ Initialization failed")
            return
        
        # Test configuration
        if hasattr(plugin, 'config'):
            print(f"✓ Configuration loaded: {len(plugin.config)} settings")
        
        # Test hooks
        test_goals = ["• Test goal 1", "• Test goal 2"]
        result = plugin.on_goals_analyzed(test_goals, "Test goals")
        print(f"✓ Goals hook: {len(test_goals)} → {len(result)} goals")
        
        # Test session hooks
        session_data = {'mode': 'test', 'duration_minutes': 30}
        plugin.on_session_start(session_data)
        plugin.on_session_update(5.0, 16.7)
        plugin.on_session_end(session_data)
        print("✓ Session hooks completed")
        
        # Test cleanup
        plugin.cleanup()
        print("✓ Cleanup completed")
        
    except Exception as e:
        print(f"✗ Plugin test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_plugin()
```

#### 2. Logging Setup
Add comprehensive logging to your plugin:

```python
import logging
import os

def setup_plugin_logging(plugin_name: str):
    """Setup logging for plugin development"""
    logger = logging.getLogger(f'focus_utility.plugin.{plugin_name}')
    
    if not logger.handlers:
        # File handler
        log_file = os.path.join(os.path.dirname(__file__), f'{plugin_name.lower()}.log')
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.DEBUG)
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        
        # Formatter
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        logger.addHandler(file_handler)
        logger.addHandler(console_handler)
        logger.setLevel(logging.DEBUG)
    
    return logger

# Use in your plugin
class MyPlugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.logger = setup_plugin_logging('my_plugin')
    
    def initialize(self):
        self.logger.info("Initializing plugin")
        # Your code here
```

### Performance Profiling

For plugins with performance issues:

```python
import time
import functools

def profile_method(func):
    """Decorator to profile method execution time"""
    @functools.wraps(func)
    def wrapper(self, *args, **kwargs):
        start_time = time.time()
        result = func(self, *args, **kwargs)
        end_time = time.time()
        
        execution_time = end_time - start_time
        if execution_time > 0.1:  # Log slow operations
            print(f"PERF: {func.__name__} took {execution_time:.3f}s")
        
        return result
    return wrapper

class ProfiledPlugin(PluginBase):
    @profile_method
    def on_goals_analyzed(self, goals, goals_text):
        # Your implementation
        return self.process_goals(goals, goals_text)
```

---

## Getting Help

### Resources

1. **Main Application Documentation**: `CODE_EXPLANATION.md`
2. **Plugin Examples**: Check the `plugins/` directory for working examples
3. **API Reference**: This document's API Reference section
4. **PyQt5 Documentation**: https://doc.qt.io/qtforpython/

### Community

1. **GitHub Issues**: Report bugs and request features
2. **Discussions**: Share plugin ideas and get help
3. **Wiki**: Community-maintained documentation

### Best Practices Summary

1. **Always inherit from `PluginBase`**
2. **Implement `initialize()` and `cleanup()` methods**
3. **Handle errors gracefully - never crash the main app**
4. **Use proper logging for debugging**
5. **Validate configuration and inputs**
6. **Keep hook methods fast and non-blocking**
7. **Provide clear user feedback**
8. **Follow semantic versioning**
9. **Test thoroughly before distribution**
10. **Document your plugin's functionality**

---

*Happy Plugin Development! 🚀*