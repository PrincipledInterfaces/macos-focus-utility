#!/usr/bin/env python3

import os
import json
import importlib.util
import sys
from typing import Dict, List, Any, Optional
from abc import ABC, abstractmethod
from PyQt5.QtCore import QObject, pyqtSignal

class PluginBase(ABC):
    """Base class that all plugins must inherit from"""
    
    def __init__(self):
        self.name = "Unknown Plugin"
        self.version = "1.0.0"
        self.description = "A focus utility plugin"
        self.enabled = False
        self._progress_popup = None  # Reference to ProgressPopup for API access
    
    @abstractmethod
    def initialize(self) -> bool:
        """Initialize the plugin. Return True if successful."""
        pass
    
    @abstractmethod
    def cleanup(self):
        """Cleanup when plugin is disabled or app closes."""
        pass
    
    def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
        """Hook called after goals are analyzed. Can modify goals list."""
        return goals
    
    def on_session_start(self, session_data: Dict[str, Any]):
        """Hook called when focus session starts."""
        pass
    
    def on_session_update(self, elapsed_minutes: float, progress_percent: float):
        """Hook called during session updates."""
        pass
    
    def on_session_end(self, session_data: Dict[str, Any]):
        """Hook called when session ends."""
        pass
    
    def on_checklist_item_changed(self, item_text: str, is_checked: bool):
        """Hook called when a checklist item is checked/unchecked."""
        pass
    
    # API methods for checklist interaction
    def get_checklist_progress_percentage(self) -> float:
        """Get the current checklist completion percentage (0-100)"""
        if self._progress_popup:
            return self._progress_popup.get_checklist_progress_percentage()
        return 0.0
    
    def get_completed_checklist_items(self) -> List[str]:
        """Get list of completed checklist items"""
        if self._progress_popup:
            return self._progress_popup.get_completed_checklist_items()
        return []
    
    def get_all_checklist_items(self) -> List[str]:
        """Get list of all checklist items"""
        if self._progress_popup:
            return self._progress_popup.get_all_checklist_items()
        return []
    
    def set_checklist_item_checked(self, item_text: str, checked: bool) -> bool:
        """Set a checklist item as checked/unchecked. Returns True if successful."""
        if self._progress_popup:
            return self._progress_popup.set_checklist_item_checked(item_text, checked)
        return False

class PluginManager(QObject):
    """Manages loading, enabling, and disabling plugins"""
    
    plugin_notification = pyqtSignal(str, str)  # title, message
    
    def __init__(self):
        super().__init__()
        self.plugins_dir = os.path.join(os.path.dirname(__file__), 'plugins')
        self.available_plugins: Dict[str, Dict] = {}
        self.loaded_plugins: Dict[str, PluginBase] = {}
        self.enabled_plugins: List[str] = []
        self.settings_file = os.path.join(os.path.dirname(__file__), 'plugin_settings.json')
        
        # Ensure plugins directory exists
        os.makedirs(self.plugins_dir, exist_ok=True)
        
        # Load settings
        self.load_settings()
        
        # Discover and load plugins
        self.discover_plugins()
        self.load_enabled_plugins()
    
    def discover_plugins(self):
        """Discover all available plugins in the plugins directory"""
        if not os.path.exists(self.plugins_dir):
            return
        
        for item in os.listdir(self.plugins_dir):
            plugin_path = os.path.join(self.plugins_dir, item)
            if os.path.isdir(plugin_path):
                manifest_path = os.path.join(plugin_path, 'manifest.json')
                if os.path.exists(manifest_path):
                    try:
                        with open(manifest_path, 'r') as f:
                            manifest = json.load(f)
                        
                        # Validate required fields
                        required_fields = ['name', 'version', 'description', 'main_file']
                        if all(field in manifest for field in required_fields):
                            manifest['path'] = plugin_path
                            self.available_plugins[item] = manifest
                        else:
                            print(f"Plugin {item} missing required manifest fields")
                    except Exception as e:
                        print(f"Error reading manifest for plugin {item}: {e}")
    
    def load_plugin(self, plugin_id: str) -> bool:
        """Load a specific plugin"""
        if plugin_id not in self.available_plugins:
            return False
        
        if plugin_id in self.loaded_plugins:
            return True  # Already loaded
        
        try:
            manifest = self.available_plugins[plugin_id]
            plugin_path = manifest['path']
            main_file = os.path.join(plugin_path, manifest['main_file'])
            
            # Import the plugin module
            spec = importlib.util.spec_from_file_location(f"plugin_{plugin_id}", main_file)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            # Get the plugin class (should be named 'Plugin')
            if hasattr(module, 'Plugin'):
                plugin_instance = module.Plugin()
                plugin_instance.name = manifest['name']
                plugin_instance.version = manifest['version']
                plugin_instance.description = manifest['description']
                
                # Initialize the plugin
                if plugin_instance.initialize():
                    self.loaded_plugins[plugin_id] = plugin_instance
                    return True
                else:
                    print(f"Failed to initialize plugin {plugin_id}")
                    return False
            else:
                print(f"Plugin {plugin_id} does not have a 'Plugin' class")
                return False
                
        except Exception as e:
            print(f"Error loading plugin {plugin_id}: {e}")
            return False
    
    def enable_plugin(self, plugin_id: str) -> bool:
        """Enable a plugin"""
        if plugin_id not in self.available_plugins:
            return False
        
        # Load plugin if not already loaded
        if not self.load_plugin(plugin_id):
            return False
        
        if plugin_id not in self.enabled_plugins:
            self.enabled_plugins.append(plugin_id)
            self.loaded_plugins[plugin_id].enabled = True
            self.save_settings()
        
        return True
    
    def disable_plugin(self, plugin_id: str) -> bool:
        """Disable a plugin"""
        if plugin_id in self.enabled_plugins:
            self.enabled_plugins.remove(plugin_id)
            if plugin_id in self.loaded_plugins:
                self.loaded_plugins[plugin_id].enabled = False
                self.loaded_plugins[plugin_id].cleanup()
            self.save_settings()
            return True
        return False
    
    def load_enabled_plugins(self):
        """Load all enabled plugins"""
        for plugin_id in self.enabled_plugins:
            self.load_plugin(plugin_id)
    
    def get_available_plugins(self) -> Dict[str, Dict]:
        """Get list of all available plugins"""
        return self.available_plugins.copy()
    
    def is_plugin_enabled(self, plugin_id: str) -> bool:
        """Check if a plugin is enabled"""
        return plugin_id in self.enabled_plugins
    
    def load_settings(self):
        """Load plugin settings from file"""
        try:
            if os.path.exists(self.settings_file):
                with open(self.settings_file, 'r') as f:
                    settings = json.load(f)
                    self.enabled_plugins = settings.get('enabled_plugins', [])
        except Exception as e:
            print(f"Error loading plugin settings: {e}")
            self.enabled_plugins = []
    
    def save_settings(self):
        """Save plugin settings to file"""
        try:
            settings = {
                'enabled_plugins': self.enabled_plugins
            }
            with open(self.settings_file, 'w') as f:
                json.dump(settings, f, indent=2)
        except Exception as e:
            print(f"Error saving plugin settings: {e}")
    
    # Hook methods to call enabled plugins
    def call_goals_analyzed_hooks(self, goals: List[str], goals_text: str) -> List[str]:
        """Call on_goals_analyzed hooks for all enabled plugins"""
        result_goals = goals.copy()
        for plugin_id in self.enabled_plugins:
            if plugin_id in self.loaded_plugins:
                try:
                    result_goals = self.loaded_plugins[plugin_id].on_goals_analyzed(result_goals, goals_text)
                except Exception as e:
                    print(f"Error in plugin {plugin_id} goals_analyzed hook: {e}")
        return result_goals
    
    def call_session_start_hooks(self, session_data: Dict[str, Any]):
        """Call on_session_start hooks for all enabled plugins"""
        print(f"DEBUG: Calling session start hooks for plugins: {self.enabled_plugins}")
        for plugin_id in self.enabled_plugins:
            if plugin_id in self.loaded_plugins:
                try:
                    print(f"DEBUG: Calling session_start hook for plugin: {plugin_id}")
                    self.loaded_plugins[plugin_id].on_session_start(session_data)
                except Exception as e:
                    print(f"Error in plugin {plugin_id} session_start hook: {e}")
                    import traceback
                    traceback.print_exc()
            else:
                print(f"DEBUG: Plugin {plugin_id} is enabled but not loaded")
    
    def call_session_update_hooks(self, elapsed_minutes: float, progress_percent: float):
        """Call on_session_update hooks for all enabled plugins"""
        for plugin_id in self.enabled_plugins:
            if plugin_id in self.loaded_plugins:
                try:
                    self.loaded_plugins[plugin_id].on_session_update(elapsed_minutes, progress_percent)
                except Exception as e:
                    print(f"Error in plugin {plugin_id} session_update hook: {e}")
    
    def call_session_end_hooks(self, session_data: Dict[str, Any]):
        """Call on_session_end hooks for all enabled plugins"""
        for plugin_id in self.enabled_plugins:
            if plugin_id in self.loaded_plugins:
                try:
                    self.loaded_plugins[plugin_id].on_session_end(session_data)
                except Exception as e:
                    print(f"Error in plugin {plugin_id} session_end hook: {e}")
    
    def call_checklist_item_changed_hooks(self, item_text: str, is_checked: bool):
        """Call on_checklist_item_changed hooks for all enabled plugins"""
        for plugin_id in self.enabled_plugins:
            if plugin_id in self.loaded_plugins:
                try:
                    self.loaded_plugins[plugin_id].on_checklist_item_changed(item_text, is_checked)
                except Exception as e:
                    print(f"Error in plugin {plugin_id} checklist_item_changed hook: {e}")
    
    def set_progress_popup_reference(self, progress_popup):
        """Set the progress popup reference for all loaded plugins"""
        for plugin in self.loaded_plugins.values():
            plugin._progress_popup = progress_popup
    
    def cleanup_all_plugins(self):
        """Cleanup all loaded plugins"""
        for plugin in self.loaded_plugins.values():
            try:
                plugin.cleanup()
            except Exception as e:
                print(f"Error cleaning up plugin: {e}")

# Global plugin manager instance
plugin_manager = PluginManager()