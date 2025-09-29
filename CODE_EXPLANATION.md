# Focus Utility - Comprehensive Code Explanation

## Overview
This is a sophisticated Python desktop application built with PyQt5 that helps users maintain focus through structured sessions with AI-powered goal analysis, application/website blocking, and an extensible plugin system. The application has evolved from a simple focus timer into a comprehensive productivity platform with modular architecture.

## Table of Contents
1. [Application Architecture](#application-architecture)
2. [Core Programming Concepts](#core-programming-concepts)
3. [User Experience Flow](#user-experience-flow)
4. [File-by-File Technical Analysis](#file-by-file-technical-analysis)
5. [Plugin System Deep Dive](#plugin-system-deep-dive)
6. [UI/UX Design Patterns](#uiux-design-patterns)
7. [System Integration](#system-integration)
8. [Advanced Programming Patterns](#advanced-programming-patterns)
9. [Error Handling & Reliability](#error-handling--reliability)
10. [Performance Optimizations](#performance-optimizations)
11. [Learning Opportunities](#learning-opportunities)

---

## Application Architecture

### High-Level System Design
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Main App      │◄──►│  Plugin System   │◄──►│   Individual    │
│ (focus_launcher)│    │ (plugin_system)  │    │    Plugins      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   UI Dialogs    │    │  Configuration   │    │ Plugin Settings │
│  (PyQt5 Widgets)│    │   Management     │    │   & Data        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ System Scripts  │    │   AI Integration │    │  External APIs  │
│  (Shell/macOS)  │    │    (Groq API)    │    │  (Email/IMAP)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Core Technologies Stack
- **Frontend**: PyQt5 (Cross-platform GUI framework)
- **Backend**: Python 3.x with asyncio capabilities
- **System Integration**: Shell scripts, subprocess calls
- **AI Integration**: Groq API for natural language processing
- **Plugin Architecture**: Dynamic module loading with importlib
- **Configuration**: JSON-based settings management
- **Email Integration**: IMAP protocol with imaplib
- **Networking**: HTTP requests for API calls

---

## Core Programming Concepts

### 1. Object-Oriented Design with Inheritance Hierarchy

```python
# Abstract base class defines contract
class PluginBase(ABC):
    @abstractmethod
    def initialize(self) -> bool:
        pass
    
    def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
        return goals  # Default implementation

# Concrete plugin implementation
class EmailPlugin(PluginBase):
    def initialize(self) -> bool:
        self.load_config()
        return True
    
    def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
        # Plugin-specific logic to enhance goals
        email_tasks = self.analyze_important_emails()
        return goals + email_tasks
```

**Key OOP Principles Demonstrated**:
- **Encapsulation**: Each dialog class manages its own state
- **Inheritance**: All dialogs inherit from QDialog/QWidget
- **Polymorphism**: Plugin hooks allow different behaviors
- **Abstraction**: PluginBase defines common interface

### 2. Event-Driven Architecture with Signal-Slot Pattern

```python
# PyQt5's sophisticated event system
class ProgressPopup(QWidget):
    def __init__(self):
        super().__init__()
        
        # Timer-based events
        self.progress_timer = QTimer()
        self.progress_timer.timeout.connect(self.update_progress)
        
        # User interaction events
        self.close_button.clicked.connect(self.handle_close)
        
        # Custom signals for inter-component communication
        self.session_complete = pyqtSignal(dict)
    
    def update_progress(self):
        # Called every second during focus session
        self.check_current_application()
        self.update_ui_elements()
        self.call_plugin_hooks()
```

**Advanced Event Concepts**:
- **Signal Emission**: Components can broadcast events
- **Multiple Connections**: One signal can trigger multiple slots
- **Cross-Thread Communication**: Signals work across threads safely

### 3. Dynamic Module Loading and Reflection

```python
class PluginManager:
    def load_plugin(self, plugin_path):
        # Dynamic module loading - loads Python code at runtime
        spec = importlib.util.spec_from_file_location(f"plugin_{plugin_id}", main_file)
        module = importlib.util.module_from_spec(spec)
        
        # Execute the module in current context
        spec.loader.exec_module(module)
        
        # Use reflection to find and instantiate plugin class
        if hasattr(module, 'Plugin'):
            plugin_instance = module.Plugin()
            
            # Verify plugin implements required interface
            if isinstance(plugin_instance, PluginBase):
                return plugin_instance
        
        raise ImportError(f"Invalid plugin structure in {plugin_path}")
```

**Advanced Python Features**:
- **importlib**: Runtime module loading
- **hasattr/getattr**: Runtime attribute inspection
- **isinstance**: Type checking at runtime

---

## User Experience Flow

### Complete Session Workflow
```
┌─────────────────┐
│ 1. Mode Selection│ → User chooses focus mode (productivity/creativity/social_media_detox)
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 2. Time Selection│ → User sets session duration (15-120 minutes)
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 3. Goals Entry  │ → User writes session goals in natural language
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 4. AI Analysis  │ → Goals processed by AI, converted to actionable tasks
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 5. Plugin Hooks │ → Plugins can add additional tasks (e.g., from emails)
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 6. Goals Review │ → User confirms final task list
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 7. Breathing    │ → Calming exercise before session starts
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 8. Focus Session│ → Timed session with periodic check-ins
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 9. Summary      │ → Review accomplishments and plan next steps
└─────────────────┘
```

### Plugin Integration Points
The plugin system provides several hooks throughout this flow:
- **on_goals_analyzed**: After AI processes goals
- **on_session_start**: When focus session begins
- **on_session_update**: During periodic check-ins
- **on_checklist_item_changed**: When user checks/unchecks goals during session
- **on_session_end**: When session completes
- **on_summary_closed**: When user closes the session summary screen

### Plugin API Methods
The plugin system also provides API methods for plugins to control the session:
- **end_session()**: Programmatically end the current focus session
- **get_checklist_progress_percentage()**: Get current goal completion percentage
- **get_completed_checklist_items()**: Get list of completed goals
- **get_all_checklist_items()**: Get all session goals
- **set_checklist_item_checked()**: Mark goals as completed/incomplete

---

## File-by-File Technical Analysis

### `focus_launcher.py` (Main Application - ~2000 lines)

This file demonstrates enterprise-level Python application structure:

#### Class Architecture Overview
```python
# Dialog Classes (UI Components)
class TimePickerDialog(QDialog)        # Session duration selection
class GoalsDialog(QDialog)             # Goal entry and AI analysis
class GoalsReviewDialog(QDialog)       # Goal confirmation
class PluginTaskDialog(QDialog)        # Plugin task integration
class FinalGoalsDialog(QDialog)        # Final task list review
class PasswordDialog(QDialog)          # Security authentication
class CountdownWindow(QWidget)         # Breathing exercise
class ProgressPopup(QWidget)           # Session monitoring with animated backgrounds
class SessionSummary(QWidget)          # Session completion with macOS Sequoia-style design

# Main Application Controller
class FocusLauncher                    # Application orchestrator
class FocusSelector(QWidget)           # Mode selection UI
```

#### Advanced PyQt5 Techniques

**1. Custom Widget Styling with CSS**
```python
def init_ui(self):
    self.setStyleSheet("""
        QDialog {
            background: qlineargradient(
                x1: 0, y1: 0, x2: 0, y2: 1,
                stop: 0 #ffffff,
                stop: 1 #f5f5f7
            );
            border-radius: 20px;
        }
        QPushButton {
            background-color: #007aff;
            border: none;
            border-radius: 8px;
            color: white;
            font-weight: 600;
            padding: 12px 24px;
        }
        QPushButton:hover {
            background-color: #0056cc;
        }
    """)
```

**2. Advanced Layout Management**
```python
def create_responsive_layout(self):
    # Nested layouts for complex UI arrangements
    main_layout = QVBoxLayout()
    
    # Header section with proper spacing
    header_layout = QVBoxLayout()
    header_layout.setSpacing(8)
    header_layout.addWidget(self.title_label)
    header_layout.addWidget(self.subtitle_label)
    
    # Content area with scroll support
    scroll_area = QScrollArea()
    content_widget = QWidget()
    content_layout = QVBoxLayout(content_widget)
    
    # Dynamic content based on data
    for item in self.data_items:
        item_widget = self.create_item_widget(item)
        content_layout.addWidget(item_widget)
    
    # Responsive button layout
    button_layout = QHBoxLayout()
    button_layout.addStretch()  # Push buttons to right
    button_layout.addWidget(self.cancel_button)
    button_layout.addWidget(self.accept_button)
```

**3. Animation System Implementation**
```python
class AnimatedProgressBar(QWidget):
    def __init__(self):
        super().__init__()
        self.current_value = 0
        self.target_value = 0
        
        # Property animation for smooth transitions
        self.animation = QPropertyAnimation(self, b"animatedValue")
        self.animation.setDuration(800)
        self.animation.setEasingCurve(QEasingCurve.OutCubic)
        
    def animateToValue(self, value):
        self.animation.setStartValue(self.current_value)
        self.animation.setEndValue(value)
        self.animation.start()
    
    # Custom property for animation
    def setAnimatedValue(self, value):
        self.current_value = value
        self.update()  # Trigger repaint
    
    animatedValue = pyqtProperty(float, fget=lambda self: self.current_value, 
                                       fset=setAnimatedValue)
```

#### AI Integration Architecture

**Multi-Provider AI System with Fallbacks**
```python
class AIAnalyzer:
    def __init__(self):
        self.providers = [
            GroqProvider(api_key=self.groq_key),
            LocalAnalyzer(),  # Fallback for offline use
        ]
    
    async def analyze_goals(self, goals_text):
        for provider in self.providers:
            try:
                result = await provider.analyze(goals_text)
                if self.validate_result(result):
                    return result
            except Exception as e:
                logger.warning(f"Provider {provider} failed: {e}")
                continue
        
        raise AIAnalysisError("All AI providers failed")
    
    def validate_result(self, result):
        # Ensure AI response has expected structure
        required_fields = ['analyzed_goals', 'priority_scores']
        return all(field in result for field in required_fields)
```

**Robust API Communication**
```python
def make_api_request(self, prompt):
    headers = {
        'Authorization': f'Bearer {self.api_key}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'model': 'llama3-8b-8192',
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.1,  # Low temperature for consistent results
        'max_tokens': 1000
    }
    
    try:
        response = requests.post(
            self.api_url,
            headers=headers,
            json=payload,
            timeout=15,
            retry=3  # Automatic retries
        )
        
        if response.status_code == 200:
            return response.json()['choices'][0]['message']['content']
        else:
            raise APIError(f"API returned {response.status_code}: {response.text}")
            
    except requests.exceptions.Timeout:
        raise TimeoutError("API request timed out")
    except requests.exceptions.ConnectionError:
        raise ConnectionError("Failed to connect to AI service")
```

### `plugin_system.py` (Plugin Infrastructure)

This file showcases advanced software architecture patterns:

#### Abstract Base Class Design
```python
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional

class PluginBase(ABC):
    """
    Abstract base class enforcing plugin contract.
    Demonstrates Interface Segregation Principio - plugins only implement what they need.
    """
    
    def __init__(self):
        # Required plugin metadata
        self.name = "Unknown Plugin"
        self.version = "1.0.0"
        self.description = "A focus utility plugin"
        self.enabled = False
    
    @abstractmethod
    def initialize(self) -> bool:
        """
        Plugin initialization - must be implemented.
        Return True if successful, False if plugin should be disabled.
        """
        pass
    
    @abstractmethod
    def cleanup(self):
        """
        Cleanup resources when plugin disabled or app closes.
        Critical for preventing memory leaks.
        """
        pass
    
    # Optional hook methods with default implementations
    def on_goals_analyzed(self, goals: List[str], goals_text: str) -> List[str]:
        """Called after AI goal analysis - plugin can modify goal list."""
        return goals
    
    def on_session_start(self, session_data: Dict[str, Any]):
        """Called when focus session begins."""
        pass
    
    def on_session_update(self, elapsed_minutes: float, progress_percent: float):
        """Called periodically during session."""
        pass
    
    def on_session_end(self, session_data: Dict[str, Any]):
        """Called when session completes."""
        pass
```

#### Plugin Manager with Advanced Features
```python
class PluginManager(QObject):
    """
    Central plugin coordinator implementing Observer pattern.
    Manages plugin lifecycle and provides event broadcasting.
    """
    
    # Qt signals for cross-component communication
    plugin_notification = pyqtSignal(str, str)  # title, message
    plugin_error = pyqtSignal(str, str)         # plugin_id, error_message
    
    def __init__(self):
        super().__init__()
        self.plugins_dir = os.path.join(os.path.dirname(__file__), 'plugins')
        self.config_file = 'plugin_settings.json'
        
        # Plugin state management
        self.available_plugins = {}  # All discovered plugins
        self.loaded_plugins = {}     # Successfully loaded plugins
        self.enabled_plugins = set() # Currently enabled plugins
        
        # Error tracking for reliability
        self.plugin_errors = {}
        self.load_attempts = {}
    
    def discover_plugins(self) -> Dict[str, Dict[str, Any]]:
        """
        Scan plugins directory and parse manifests.
        Returns metadata for all valid plugins found.
        """
        discovered = {}
        
        if not os.path.exists(self.plugins_dir):
            os.makedirs(self.plugins_dir)
            return discovered
        
        for item in os.listdir(self.plugins_dir):
            plugin_path = os.path.join(self.plugins_dir, item)
            
            if not os.path.isdir(plugin_path):
                continue
            
            manifest_path = os.path.join(plugin_path, 'manifest.json')
            
            if os.path.exists(manifest_path):
                try:
                    with open(manifest_path, 'r') as f:
                        manifest = json.load(f)
                    
                    # Validate required manifest fields
                    required_fields = ['name', 'version', 'main_file']
                    if all(field in manifest for field in required_fields):
                        discovered[item] = manifest
                        
                except json.JSONDecodeError as e:
                    logger.error(f"Invalid manifest.json in {item}: {e}")
                except Exception as e:
                    logger.error(f"Error reading manifest for {item}: {e}")
        
        return discovered
    
    def load_plugin(self, plugin_id: str) -> bool:
        """
        Dynamically load and initialize plugin.
        Demonstrates advanced Python reflection and error handling.
        """
        if plugin_id in self.loaded_plugins:
            return True
        
        if plugin_id not in self.available_plugins:
            logger.error(f"Plugin {plugin_id} not found in available plugins")
            return False
        
        manifest = self.available_plugins[plugin_id]
        plugin_path = os.path.join(self.plugins_dir, plugin_id)
        main_file = os.path.join(plugin_path, manifest['main_file'])
        
        if not os.path.exists(main_file):
            logger.error(f"Main file {main_file} not found for plugin {plugin_id}")
            return False
        
        try:
            # Dynamic module loading
            spec = importlib.util.spec_from_file_location(f"plugin_{plugin_id}", main_file)
            module = importlib.util.module_from_spec(spec)
            
            # Add plugin path to sys.path for relative imports
            sys.path.insert(0, plugin_path)
            
            try:
                spec.loader.exec_module(module)
                
                # Look for Plugin class in module
                if hasattr(module, 'Plugin'):
                    plugin_class = getattr(module, 'Plugin')
                    plugin_instance = plugin_class()
                    
                    # Verify plugin implements required interface
                    if not isinstance(plugin_instance, PluginBase):
                        raise TypeError(f"Plugin class must inherit from PluginBase")
                    
                    # Initialize plugin
                    if plugin_instance.initialize():
                        self.loaded_plugins[plugin_id] = plugin_instance
                        logger.info(f"Successfully loaded plugin: {plugin_id}")
                        return True
                    else:
                        logger.warning(f"Plugin {plugin_id} initialization failed")
                        return False
                        
                else:
                    raise AttributeError("Plugin module must contain a 'Plugin' class")
                    
            finally:
                # Clean up sys.path
                if plugin_path in sys.path:
                    sys.path.remove(plugin_path)
        
        except Exception as e:
            logger.error(f"Error loading plugin {plugin_id}: {e}")
            self.plugin_errors[plugin_id] = str(e)
            self.plugin_error.emit(plugin_id, str(e))
            return False
```

#### Hook Broadcasting System
```python
def call_goals_analyzed_hooks(self, goals: List[str], goals_text: str) -> List[str]:
    """
    Broadcast goal analysis completion to all enabled plugins.
    Each plugin can modify the goals list.
    """
    modified_goals = goals.copy()
    
    for plugin_id in self.enabled_plugins:
        if plugin_id in self.loaded_plugins:
            try:
                plugin = self.loaded_plugins[plugin_id]
                modified_goals = plugin.on_goals_analyzed(modified_goals, goals_text)
                
                # Validate plugin didn't break the goals list
                if not isinstance(modified_goals, list):
                    logger.warning(f"Plugin {plugin_id} returned invalid goals type")
                    modified_goals = goals.copy()
                    
            except Exception as e:
                logger.error(f"Error in {plugin_id}.on_goals_analyzed: {e}")
                # Continue with other plugins even if one fails
    
    return modified_goals
```

### `plugin_settings_dialog.py` (Plugin Management UI)

Demonstrates advanced UI patterns:

#### Dynamic UI Generation
```python
class PluginSettingsDialog(QMainWindow):
    def load_plugins(self):
        """Generate UI elements dynamically based on discovered plugins."""
        available_plugins = plugin_manager.get_available_plugins()
        
        if not available_plugins:
            self.show_empty_state()
            return
        
        for plugin_id, manifest in available_plugins.items():
            plugin_widget = self.create_plugin_widget(plugin_id, manifest)
            self.plugins_layout.addWidget(plugin_widget)
    
    def create_plugin_widget(self, plugin_id: str, manifest: Dict[str, Any]) -> QWidget:
        """Create a rich plugin card with status, controls, and metadata."""
        card = QFrame()
        card.setStyleSheet(self.get_card_stylesheet())
        
        layout = QVBoxLayout(card)
        
        # Header with checkbox and plugin name
        header = self.create_plugin_header(plugin_id, manifest)
        layout.addWidget(header)
        
        # Plugin description
        description = QLabel(manifest['description'])
        description.setWordWrap(True)
        description.setStyleSheet(self.get_description_stylesheet())
        layout.addWidget(description)
        
        # Plugin-specific configuration
        if plugin_id == 'email_assistant':
            config_section = self.create_email_config_section(plugin_id)
            layout.addWidget(config_section)
        
        return card
    
    def create_email_config_section(self, plugin_id: str) -> QWidget:
        """Create plugin-specific configuration UI."""
        section = QWidget()
        layout = QHBoxLayout(section)
        
        # Status display
        status_label = QLabel(self.get_email_plugin_status(plugin_id))
        status_label.setStyleSheet("font-size: 12px; color: #86868b; font-style: italic;")
        
        # Configure button
        config_btn = QPushButton("Configure Email")
        config_btn.clicked.connect(lambda: self.configure_email_plugin(plugin_id))
        config_btn.setStyleSheet(self.get_config_button_stylesheet())
        
        layout.addWidget(status_label)
        layout.addStretch()
        layout.addWidget(config_btn)
        
        return section
```

### Email Plugin (`plugins/email_assistant/plugin.py`)

Demonstrates enterprise-level email integration:

#### IMAP Protocol Implementation
```python
class EmailPlugin(PluginBase):
    def get_recent_emails(self, hours=2) -> List[Dict[str, Any]]:
        """
        Secure IMAP email retrieval with comprehensive error handling.
        """
        if not self.email_config:
            logger.warning("No email configuration available")
            return []
        
        try:
            # Establish secure IMAP connection
            server = self.email_config['server']
            email_addr = self.email_config['email']
            password = self.email_config['password']
            
            # Use SSL for security
            mail = imaplib.IMAP4_SSL(server, 993)
            
            # Authenticate with app password or regular password
            login_result = mail.login(email_addr, password)
            logger.info(f"IMAP login successful: {login_result}")
            
            # Select inbox folder
            select_result = mail.select('inbox')
            logger.info(f"Inbox selected: {select_result}")
            
            # Search for recent emails using IMAP date format
            since_date = (datetime.now() - timedelta(hours=hours)).strftime('%d-%b-%Y')
            search_criteria = f'(SINCE "{since_date}")'
            result, messages = mail.search(None, search_criteria)
            
            emails = []
            if result == 'OK' and messages[0]:
                message_ids = messages[0].split()
                
                # Process most recent emails first (limit for performance)
                for msg_id in reversed(message_ids[-10:]):
                    try:
                        email_data = self.fetch_and_parse_email(mail, msg_id)
                        if email_data:
                            emails.append(email_data)
                    except Exception as e:
                        logger.warning(f"Error processing email {msg_id}: {e}")
                        continue
            
            mail.logout()
            return emails
            
        except imaplib.IMAP4.error as e:
            logger.error(f"IMAP protocol error: {e}")
            return []
        except Exception as e:
            logger.error(f"Email retrieval error: {e}")
            return []
    
    def fetch_and_parse_email(self, mail, msg_id) -> Optional[Dict[str, Any]]:
        """Parse individual email message with MIME handling."""
        result, msg_data = mail.fetch(msg_id, '(RFC822)')
        
        if result != 'OK' or not msg_data[0] or len(msg_data[0]) < 2:
            return None
        
        # Parse raw email data
        email_body = msg_data[0][1]
        email_message = email.message_from_bytes(email_body)
        
        # Extract headers safely
        subject = self.decode_header_safely(email_message['Subject']) or 'No Subject'
        from_addr = self.decode_header_safely(email_message['From']) or 'Unknown Sender'
        date_str = email_message['Date'] or ''
        
        # Extract body content
        body = self.extract_email_body(email_message)
        
        return {
            'subject': subject,
            'from': from_addr,
            'date': date_str,
            'body': body[:500],  # Limit body length for processing
            'message_id': email_message['Message-ID']
        }
    
    def extract_email_body(self, email_message) -> str:
        """
        Extract plain text from potentially complex MIME structure.
        Handles multipart messages, different encodings, and attachments.
        """
        try:
            if email_message.is_multipart():
                # Walk through all parts of multipart message
                for part in email_message.walk():
                    content_type = part.get_content_type()
                    content_disposition = str(part.get('Content-Disposition', ''))
                    
                    # Look for plain text parts that aren't attachments
                    if (content_type == "text/plain" and 
                        'attachment' not in content_disposition):
                        
                        payload = part.get_payload(decode=True)
                        if payload:
                            # Handle different character encodings
                            charset = part.get_content_charset() or 'utf-8'
                            return payload.decode(charset, errors='ignore')
            else:
                # Simple single-part message
                payload = email_message.get_payload(decode=True)
                if payload:
                    charset = email_message.get_content_charset() or 'utf-8'
                    return payload.decode(charset, errors='ignore')
                    
        except Exception as e:
            logger.warning(f"Error extracting email body: {e}")
        
        return ""
```

#### Intelligent Email Analysis
```python
def analyze_email_importance(self, email_data: Dict[str, Any]) -> Optional[str]:
    """
    Multi-factor email importance analysis using NLP techniques.
    """
    subject = email_data['subject'].lower()
    body = email_data['body'].lower()
    from_addr = email_data['from'].lower()
    
    importance_score = 0
    task_indicators = []
    
    # 1. Urgency keyword analysis
    urgent_keywords = {
        'critical': 5, 'urgent': 4, 'asap': 4, 'deadline': 3,
        'important': 2, 'priority': 2, 'time-sensitive': 4
    }
    
    for keyword, weight in urgent_keywords.items():
        if keyword in subject or keyword in body:
            importance_score += weight
            task_indicators.append(f"urgent_{keyword}")
    
    # 2. Action verb detection
    action_verbs = {
        'review': 3, 'approve': 4, 'sign': 4, 'complete': 3,
        'submit': 3, 'respond': 2, 'call': 3, 'meeting': 3
    }
    
    for verb, weight in action_verbs.items():
        if verb in subject or verb in body:
            importance_score += weight
            task_indicators.append(f"action_{verb}")
    
    # 3. Question detection (often requires response)
    question_count = subject.count('?') + body.count('?')
    if question_count > 0:
        importance_score += min(question_count * 2, 6)
        task_indicators.append("questions_found")
    
    # 4. Meeting/appointment detection
    meeting_keywords = ['meeting', 'appointment', 'schedule', 'calendar', 'zoom', 'teams']
    meeting_found = any(keyword in subject or keyword in body for keyword in meeting_keywords)
    if meeting_found:
        importance_score += 4
        task_indicators.append("meeting_related")
    
    # 5. Sender reputation (avoid automated emails)
    automated_senders = ['noreply', 'no-reply', 'donotreply', 'notification', 'automated', 'system']
    is_automated = any(sender in from_addr for sender in automated_senders)
    
    if is_automated:
        importance_score *= 0.1  # Heavily penalize automated emails
    
    # 6. Generate task suggestion if important enough
    if importance_score >= 3 and not is_automated:
        task_type = self.classify_task_type(task_indicators, email_data)
        return self.generate_task_description(task_type, email_data)
    
    return None

def generate_task_description(self, task_type: str, email_data: Dict[str, Any]) -> str:
    """Generate human-readable task description based on email analysis."""
    sender = email_data['from'].split('<')[0].strip()
    subject = email_data['subject']
    
    task_templates = {
        'meeting': f"Schedule/attend meeting with {sender}: {subject}",
        'review': f"Review and respond to {sender}: {subject}",
        'urgent': f"Handle urgent request from {sender}: {subject}",
        'question': f"Answer questions from {sender}: {subject}",
        'action': f"Complete action requested by {sender}: {subject}",
        'default': f"Follow up on email from {sender}: {subject}"
    }
    
    return task_templates.get(task_type, task_templates['default'])
```

---

## Plugin System Deep Dive

### Plugin Architecture Philosophy

The plugin system follows several key design principles:

1. **Loose Coupling**: Plugins communicate with the main app through well-defined interfaces
2. **High Cohesion**: Each plugin focuses on a single responsibility
3. **Fail-Safe Operation**: Plugin failures don't crash the main application
4. **Hot-Swappable**: Plugins can be enabled/disabled without restarting
5. **Discoverable**: New plugins are automatically detected

### Plugin Lifecycle Management

```python
class PluginLifecycleManager:
    """Manages the complete lifecycle of plugins from discovery to cleanup."""
    
    def __init__(self):
        self.state_transitions = {
            'discovered': ['loading'],
            'loading': ['loaded', 'failed'],
            'loaded': ['initializing'],
            'initializing': ['active', 'failed'],
            'active': ['disabled', 'updating'],
            'disabled': ['active', 'unloaded'],
            'failed': ['loading', 'unloaded'],
            'updating': ['active', 'failed'],
            'unloaded': []
        }
        
        self.plugin_states = {}
    
    def transition_plugin_state(self, plugin_id: str, new_state: str):
        """Safely transition plugin between states with validation."""
        current_state = self.plugin_states.get(plugin_id, 'discovered')
        
        if new_state not in self.state_transitions.get(current_state, []):
            raise InvalidStateTransition(
                f"Cannot transition {plugin_id} from {current_state} to {new_state}"
            )
        
        self.plugin_states[plugin_id] = new_state
        self.log_state_change(plugin_id, current_state, new_state)
        
        # Trigger state-specific actions
        self.handle_state_change(plugin_id, new_state)
```

### Security and Sandboxing

```python
class PluginSandbox:
    """
    Provides security boundaries for plugin execution.
    Prevents plugins from accessing sensitive system resources.
    """
    
    def __init__(self):
        self.allowed_modules = {
            'json', 'datetime', 'typing', 'abc', 'os.path',
            'PyQt5.QtCore', 'PyQt5.QtWidgets', 'PyQt5.QtGui',
            'requests', 'imaplib', 'email', 'subprocess'
        }
        
        self.forbidden_operations = {
            'open': self.check_file_access,
            'subprocess.run': self.check_subprocess_call,
            'eval': lambda *args: False,  # Always forbidden
            'exec': lambda *args: False,  # Always forbidden
        }
    
    def validate_plugin_imports(self, plugin_code: str) -> bool:
        """Scan plugin code for potentially dangerous imports."""
        import ast
        
        try:
            tree = ast.parse(plugin_code)
            
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        if alias.name not in self.allowed_modules:
                            logger.warning(f"Plugin imports forbidden module: {alias.name}")
                            return False
                            
                elif isinstance(node, ast.ImportFrom):
                    if node.module not in self.allowed_modules:
                        logger.warning(f"Plugin imports from forbidden module: {node.module}")
                        return False
            
            return True
            
        except SyntaxError:
            logger.error("Plugin contains syntax errors")
            return False
    
    def check_file_access(self, filepath: str, mode: str) -> bool:
        """Validate file access requests from plugins."""
        # Only allow access to plugin's own directory and config files
        plugin_dir = os.path.dirname(filepath)
        allowed_patterns = [
            r'.*/plugins/.*/.*\.json$',  # Plugin config files
            r'.*/plugins/.*/.*\.log$',   # Plugin log files
        ]
        
        return any(re.match(pattern, filepath) for pattern in allowed_patterns)
```

---

## UI/UX Design Patterns

### Modern macOS-Style Interface

The application follows Apple's Human Interface Guidelines:

```python
class ModernDialogMixin:
    """Mixin providing consistent modern styling across all dialogs."""
    
    def apply_modern_styling(self):
        self.setStyleSheet("""
            QDialog {
                background-color: #fafafa;
                border-radius: 12px;
            }
            
            QLabel {
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display';
                color: #1d1d1f;
            }
            
            QPushButton {
                background-color: #007aff;
                border: none;
                border-radius: 8px;
                color: white;
                font-weight: 600;
                padding: 10px 20px;
                font-size: 14px;
            }
            
            QPushButton:hover {
                background-color: #0056cc;
            }
            
            QPushButton:pressed {
                background-color: #004494;
            }
            
            QLineEdit, QTextEdit {
                border: 1px solid #d1d1d6;
                border-radius: 8px;
                padding: 8px 12px;
                font-size: 14px;
                background-color: white;
            }
            
            QLineEdit:focus, QTextEdit:focus {
                border-color: #007aff;
                outline: none;
            }
        """)
```

### Responsive Layout System

```python
class ResponsiveLayoutManager:
    """Manages adaptive layouts that respond to content and window size."""
    
    def __init__(self, parent_widget):
        self.parent = parent_widget
        self.breakpoints = {
            'small': 400,
            'medium': 600,
            'large': 800
        }
    
    def create_adaptive_layout(self, content_items):
        """Create layout that adapts to content and screen size."""
        current_width = self.parent.width()
        
        if current_width < self.breakpoints['small']:
            return self.create_compact_layout(content_items)
        elif current_width < self.breakpoints['medium']:
            return self.create_standard_layout(content_items)
        else:
            return self.create_spacious_layout(content_items)
    
    def create_compact_layout(self, items):
        """Vertical layout for narrow screens."""
        layout = QVBoxLayout()
        layout.setSpacing(8)
        
        for item in items:
            compact_widget = self.create_compact_widget(item)
            layout.addWidget(compact_widget)
        
        return layout
    
    def create_spacious_layout(self, items):
        """Multi-column layout for wide screens."""
        main_layout = QHBoxLayout()
        
        # Split items into columns
        items_per_column = len(items) // 2
        left_column = QVBoxLayout()
        right_column = QVBoxLayout()
        
        for i, item in enumerate(items):
            target_column = left_column if i < items_per_column else right_column
            widget = self.create_standard_widget(item)
            target_column.addWidget(widget)
        
        main_layout.addLayout(left_column)
        main_layout.addLayout(right_column)
        
        return main_layout
```

### Animation and Visual Feedback

```python
class AnimationController:
    """Manages smooth animations and visual feedback throughout the app."""
    
    def __init__(self):
        self.active_animations = {}
        self.animation_queue = []
    
    def fade_in_widget(self, widget, duration=300):
        """Smooth fade-in animation for better UX."""
        effect = QGraphicsOpacityEffect()
        widget.setGraphicsEffect(effect)
        
        animation = QPropertyAnimation(effect, b"opacity")
        animation.setDuration(duration)
        animation.setStartValue(0.0)
        animation.setEndValue(1.0)
        animation.setEasingCurve(QEasingCurve.OutCubic)
        
        animation.start()
        self.active_animations[widget] = animation
        
        return animation
    
    def slide_in_widget(self, widget, direction='left', duration=400):
        """Slide animation for dialog transitions."""
        start_pos = widget.pos()
        
        if direction == 'left':
            widget.move(start_pos.x() - widget.width(), start_pos.y())
        elif direction == 'right':
            widget.move(start_pos.x() + widget.width(), start_pos.y())
        
        animation = QPropertyAnimation(widget, b"pos")
        animation.setDuration(duration)
        animation.setEndValue(start_pos)
        animation.setEasingCurve(QEasingCurve.OutBack)
        
        widget.show()
        animation.start()
        
        return animation
    
    def create_progress_animation(self, progress_bar, target_value):
        """Animated progress updates for better visual feedback."""
        animation = QPropertyAnimation(progress_bar, b"value")
        animation.setDuration(800)
        animation.setStartValue(progress_bar.value())
        animation.setEndValue(target_value)
        animation.setEasingCurve(QEasingCurve.OutCubic)
        
        return animation
```

---

## System Integration

### macOS System Interaction

The application integrates deeply with macOS:

```python
class MacOSIntegration:
    """Handles macOS-specific system operations."""
    
    def __init__(self):
        self.blocked_apps = set()
        self.original_hosts_backup = None
    
    def get_active_application(self) -> str:
        """Get currently focused application using AppleScript."""
        script = '''
        tell application "System Events"
            get name of first application process whose frontmost is true
        end tell
        '''
        
        try:
            result = subprocess.run(
                ['osascript', '-e', script],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                logger.warning(f"AppleScript error: {result.stderr}")
                return "Unknown"
                
        except subprocess.TimeoutExpired:
            logger.warning("AppleScript timeout")
            return "Unknown"
        except Exception as e:
            logger.error(f"Error getting active app: {e}")
            return "Unknown"
    
    def block_applications(self, app_list: List[str]):
        """Block specified applications using launchctl."""
        for app in app_list:
            try:
                # Find application bundle identifier
                bundle_id = self.get_bundle_identifier(app)
                
                if bundle_id:
                    # Use launchctl to prevent app launch
                    result = subprocess.run([
                        'sudo', 'launchctl', 'disable', f'gui/{os.getuid()}/{bundle_id}'
                    ], capture_output=True, text=True)
                    
                    if result.returncode == 0:
                        self.blocked_apps.add(bundle_id)
                        logger.info(f"Blocked application: {app} ({bundle_id})")
                    else:
                        logger.warning(f"Failed to block {app}: {result.stderr}")
                        
            except Exception as e:
                logger.error(f"Error blocking {app}: {e}")
    
    def get_bundle_identifier(self, app_name: str) -> Optional[str]:
        """Get bundle identifier for application name."""
        script = f'''
        tell application "System Events"
            set appPath to (path to applications folder as string) & "{app_name}.app"
            try
                set bundleID to bundle identifier of application file appPath
                return bundleID
            on error
                return ""
            end try
        end tell
        '''
        
        try:
            result = subprocess.run(
                ['osascript', '-e', script],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
                
        except Exception as e:
            logger.error(f"Error getting bundle ID for {app_name}: {e}")
        
        return None
    
    def modify_hosts_file(self, blocked_domains: List[str]):
        """Modify /etc/hosts to block websites."""
        hosts_path = '/etc/hosts'
        backup_path = '/tmp/focus_hosts_backup'
        
        try:
            # Create backup
            subprocess.run(['sudo', 'cp', hosts_path, backup_path], check=True)
            self.original_hosts_backup = backup_path
            
            # Add blocking entries
            with open('/tmp/focus_block_entries', 'w') as f:
                f.write('\n# Focus Utility - Temporary blocks\n')
                for domain in blocked_domains:
                    f.write(f'127.0.0.1 {domain}\n')
                    f.write(f'127.0.0.1 www.{domain}\n')
                f.write('# End Focus Utility blocks\n')
            
            # Append to hosts file
            subprocess.run([
                'sudo', 'sh', '-c', f'cat /tmp/focus_block_entries >> {hosts_path}'
            ], check=True)
            
            # Flush DNS cache
            subprocess.run(['sudo', 'dscacheutil', '-flushcache'], check=True)
            subprocess.run(['sudo', 'killall', '-HUP', 'mDNSResponder'], check=True)
            
            logger.info(f"Blocked {len(blocked_domains)} domains")
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to modify hosts file: {e}")
        except Exception as e:
            logger.error(f"Unexpected error modifying hosts: {e}")
    
    def restore_system_state(self):
        """Restore original system state after focus session."""
        try:
            # Restore hosts file
            if self.original_hosts_backup:
                subprocess.run([
                    'sudo', 'cp', self.original_hosts_backup, '/etc/hosts'
                ], check=True)
                
                # Flush DNS again
                subprocess.run(['sudo', 'dscacheutil', '-flushcache'], check=True)
            
            # Re-enable blocked applications
            for bundle_id in self.blocked_apps:
                subprocess.run([
                    'sudo', 'launchctl', 'enable', f'gui/{os.getuid()}/{bundle_id}'
                ], capture_output=True)
            
            self.blocked_apps.clear()
            logger.info("System state restored")
            
        except Exception as e:
            logger.error(f"Error restoring system state: {e}")
```

### Cross-Platform Considerations

```python
class PlatformManager:
    """Handles platform-specific operations with graceful fallbacks."""
    
    def __init__(self):
        self.platform = sys.platform
        self.integration = self.create_platform_integration()
    
    def create_platform_integration(self):
        """Factory method for platform-specific integrations."""
        if self.platform == 'darwin':
            return MacOSIntegration()
        elif self.platform == 'win32':
            return WindowsIntegration()
        elif self.platform.startswith('linux'):
            return LinuxIntegration()
        else:
            return GenericIntegration()
    
    def show_notification(self, title: str, message: str):
        """Show system notification with platform-appropriate method."""
        if self.platform == 'darwin':
            self.show_macos_notification(title, message)
        elif self.platform == 'win32':
            self.show_windows_notification(title, message)
        else:
            self.show_generic_notification(title, message)
    
    def show_macos_notification(self, title: str, message: str):
        """macOS notification using osascript."""
        script = f'''
        display notification "{message}" with title "{title}" sound name "default"
        '''
        
        try:
            subprocess.run(['osascript', '-e', script], check=True)
        except Exception as e:
            logger.error(f"Failed to show macOS notification: {e}")
```

---

## Advanced Programming Patterns

### Dependency Injection

```python
class ServiceContainer:
    """Dependency injection container for managing service dependencies."""
    
    def __init__(self):
        self.services = {}
        self.singletons = {}
        self.factories = {}
    
    def register_singleton(self, interface: type, implementation: type):
        """Register a singleton service."""
        self.singletons[interface] = implementation
    
    def register_factory(self, interface: type, factory_func):
        """Register a factory function for creating service instances."""
        self.factories[interface] = factory_func
    
    def get(self, interface: type):
        """Resolve and return service instance."""
        if interface in self.services:
            return self.services[interface]
        
        if interface in self.singletons:
            implementation = self.singletons[interface]
            instance = implementation()
            self.services[interface] = instance
            return instance
        
        if interface in self.factories:
            factory = self.factories[interface]
            return factory()
        
        raise ServiceNotRegistered(f"No service registered for {interface}")

# Usage in the application
container = ServiceContainer()
container.register_singleton(PluginManager, PluginManager)
container.register_factory(AIAnalyzer, lambda: AIAnalyzer(api_key=get_api_key()))

# Plugins can request services
class EmailPlugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.plugin_manager = container.get(PluginManager)
        self.ai_analyzer = container.get(AIAnalyzer)
```

### Command Pattern for Undo/Redo

```python
class Command(ABC):
    """Abstract command for implementing undo/redo functionality."""
    
    @abstractmethod
    def execute(self):
        pass
    
    @abstractmethod
    def undo(self):
        pass

class ChangeGoalCommand(Command):
    """Command for modifying goals with undo support."""
    
    def __init__(self, goals_dialog, old_goals, new_goals):
        self.dialog = goals_dialog
        self.old_goals = old_goals.copy()
        self.new_goals = new_goals.copy()
    
    def execute(self):
        self.dialog.set_goals(self.new_goals)
    
    def undo(self):
        self.dialog.set_goals(self.old_goals)

class CommandHistory:
    """Manages command history for undo/redo operations."""
    
    def __init__(self, max_history=50):
        self.history = []
        self.current_index = -1
        self.max_history = max_history
    
    def execute_command(self, command: Command):
        """Execute command and add to history."""
        command.execute()
        
        # Remove any commands after current index (if we're in middle of history)
        self.history = self.history[:self.current_index + 1]
        
        # Add new command
        self.history.append(command)
        self.current_index += 1
        
        # Maintain history size limit
        if len(self.history) > self.max_history:
            self.history.pop(0)
            self.current_index -= 1
    
    def undo(self):
        """Undo the last command."""
        if self.can_undo():
            command = self.history[self.current_index]
            command.undo()
            self.current_index -= 1
            return True
        return False
    
    def redo(self):
        """Redo the next command."""
        if self.can_redo():
            self.current_index += 1
            command = self.history[self.current_index]
            command.execute()
            return True
        return False
```

### State Machine Pattern

```python
class SessionState(Enum):
    IDLE = "idle"
    CONFIGURING = "configuring"
    PREPARING = "preparing"
    BREATHING = "breathing"
    ACTIVE = "active"
    PAUSED = "paused"
    ENDING = "ending"
    COMPLETE = "complete"

class SessionStateMachine:
    """Manages session state transitions with validation."""
    
    def __init__(self):
        self.current_state = SessionState.IDLE
        self.state_handlers = {
            SessionState.IDLE: self.handle_idle_state,
            SessionState.CONFIGURING: self.handle_configuring_state,
            SessionState.PREPARING: self.handle_preparing_state,
            # ... other state handlers
        }
        
        self.valid_transitions = {
            SessionState.IDLE: [SessionState.CONFIGURING],
            SessionState.CONFIGURING: [SessionState.PREPARING, SessionState.IDLE],
            SessionState.PREPARING: [SessionState.BREATHING, SessionState.IDLE],
            SessionState.BREATHING: [SessionState.ACTIVE, SessionState.IDLE],
            SessionState.ACTIVE: [SessionState.PAUSED, SessionState.ENDING],
            SessionState.PAUSED: [SessionState.ACTIVE, SessionState.ENDING],
            SessionState.ENDING: [SessionState.COMPLETE],
            SessionState.COMPLETE: [SessionState.IDLE]
        }
    
    def transition_to(self, new_state: SessionState):
        """Transition to new state with validation."""
        if new_state not in self.valid_transitions.get(self.current_state, []):
            raise InvalidStateTransition(
                f"Cannot transition from {self.current_state} to {new_state}"
            )
        
        old_state = self.current_state
        self.current_state = new_state
        
        # Call state handler
        if new_state in self.state_handlers:
            self.state_handlers[new_state]()
        
        # Emit transition event
        self.on_state_changed(old_state, new_state)
    
    def handle_active_state(self):
        """Handle entering active focus state."""
        # Start blocking applications and websites
        self.block_distractions()
        
        # Begin progress monitoring
        self.start_progress_monitoring()
        
        # Notify plugins
        self.notify_session_start()
```

---

## Error Handling & Reliability

### Comprehensive Error Management

```python
class FocusUtilityError(Exception):
    """Base exception for all application errors."""
    pass

class PluginError(FocusUtilityError):
    """Plugin-related errors."""
    pass

class AIAnalysisError(FocusUtilityError):
    """AI service errors."""
    pass

class SystemIntegrationError(FocusUtilityError):
    """System-level operation errors."""
    pass

class ErrorHandler:
    """Centralized error handling with user-friendly reporting."""
    
    def __init__(self):
        self.error_log = []
        self.error_callbacks = {}
        self.max_log_size = 1000
    
    def handle_error(self, error: Exception, context: str = "", user_facing: bool = True):
        """Handle error with appropriate logging and user notification."""
        error_info = {
            'timestamp': datetime.now(),
            'error_type': type(error).__name__,
            'message': str(error),
            'context': context,
            'traceback': traceback.format_exc() if logger.isEnabledFor(logging.DEBUG) else None
        }
        
        # Log error
        self.error_log.append(error_info)
        if len(self.error_log) > self.max_log_size:
            self.error_log.pop(0)
        
        # Log to file
        logger.error(f"{context}: {error}", exc_info=True)
        
        # Handle specific error types
        if isinstance(error, PluginError):
            self.handle_plugin_error(error, context)
        elif isinstance(error, AIAnalysisError):
            self.handle_ai_error(error, context)
        elif isinstance(error, SystemIntegrationError):
            self.handle_system_error(error, context)
        
        # Notify user if appropriate
        if user_facing:
            self.show_user_error_message(error, context)
    
    def handle_plugin_error(self, error: PluginError, context: str):
        """Handle plugin-specific errors gracefully."""
        # Disable problematic plugin
        plugin_id = self.extract_plugin_id_from_context(context)
        if plugin_id:
            plugin_manager.disable_plugin(plugin_id, reason=str(error))
        
        # Continue application operation without the plugin
        logger.warning(f"Plugin {plugin_id} disabled due to error: {error}")
    
    def show_user_error_message(self, error: Exception, context: str):
        """Show user-friendly error message."""
        user_messages = {
            PluginError: "A plugin encountered an error and has been disabled. The application will continue normally.",
            AIAnalysisError: "AI analysis is temporarily unavailable. Your goals will be processed using local analysis.",
            SystemIntegrationError: "A system operation failed. Some features may be limited.",
            Exception: "An unexpected error occurred. Please try again."
        }
        
        error_type = type(error)
        message = user_messages.get(error_type, user_messages[Exception])
        
        # Show non-blocking notification
        QTimer.singleShot(100, lambda: self.show_error_notification(message))
    
    def show_error_notification(self, message: str):
        """Show error notification without blocking UI."""
        notification = QMessageBox()
        notification.setIcon(QMessageBox.Warning)
        notification.setWindowTitle("Focus Utility")
        notification.setText(message)
        notification.setStandardButtons(QMessageBox.Ok)
        notification.show()
```

### Graceful Degradation

```python
class FeatureManager:
    """Manages feature availability with graceful degradation."""
    
    def __init__(self):
        self.available_features = {
            'ai_analysis': True,
            'email_integration': True,
            'system_blocking': True,
            'notifications': True
        }
        
        self.feature_fallbacks = {
            'ai_analysis': self.local_goal_analysis,
            'email_integration': self.skip_email_analysis,
            'system_blocking': self.show_blocking_reminder,
            'notifications': self.log_notification
        }
    
    def use_feature(self, feature_name: str, primary_function, *args, **kwargs):
        """Use feature with automatic fallback on failure."""
        if not self.available_features.get(feature_name, False):
            return self.use_fallback(feature_name, *args, **kwargs)
        
        try:
            return primary_function(*args, **kwargs)
        except Exception as e:
            logger.warning(f"Feature {feature_name} failed: {e}")
            self.available_features[feature_name] = False
            return self.use_fallback(feature_name, *args, **kwargs)
    
    def use_fallback(self, feature_name: str, *args, **kwargs):
        """Use fallback implementation for failed feature."""
        fallback = self.feature_fallbacks.get(feature_name)
        if fallback:
            logger.info(f"Using fallback for {feature_name}")
            return fallback(*args, **kwargs)
        else:
            logger.error(f"No fallback available for {feature_name}")
            return None
    
    def local_goal_analysis(self, goals_text: str):
        """Local fallback for AI goal analysis."""
        # Simple keyword-based analysis
        lines = goals_text.strip().split('\n')
        analyzed_goals = []
        
        for line in lines:
            line = line.strip()
            if line and not line.startswith('#'):
                # Add bullet point if missing
                if not line.startswith('•') and not line.startswith('-'):
                    line = f"• {line}"
                analyzed_goals.append(line)
        
        return {
            'analyzed_goals': analyzed_goals,
            'source': 'local_analysis',
            'confidence': 0.7
        }
```

---

## Performance Optimizations

### Lazy Loading and Caching

```python
class LazyLoader:
    """Implements lazy loading pattern for expensive resources."""
    
    def __init__(self):
        self.loaded_resources = {}
        self.loading_locks = {}
    
    def get_resource(self, resource_key: str, loader_func):
        """Get resource with lazy loading and caching."""
        if resource_key in self.loaded_resources:
            return self.loaded_resources[resource_key]
        
        # Prevent multiple concurrent loads of same resource
        if resource_key in self.loading_locks:
            self.loading_locks[resource_key].wait()
            return self.loaded_resources.get(resource_key)
        
        # Load resource
        self.loading_locks[resource_key] = threading.Event()
        
        try:
            resource = loader_func()
            self.loaded_resources[resource_key] = resource
            return resource
        finally:
            self.loading_locks[resource_key].set()
            del self.loading_locks[resource_key]

class PluginCache:
    """Caching system for plugin operations."""
    
    def __init__(self, max_size=100, ttl_seconds=300):
        self.cache = {}
        self.access_times = {}
        self.max_size = max_size
        self.ttl_seconds = ttl_seconds
    
    def get(self, key: str, default=None):
        """Get cached value with TTL checking."""
        if key not in self.cache:
            return default
        
        # Check TTL
        if time.time() - self.access_times[key] > self.ttl_seconds:
            del self.cache[key]
            del self.access_times[key]
            return default
        
        # Update access time
        self.access_times[key] = time.time()
        return self.cache[key]
    
    def set(self, key: str, value):
        """Set cached value with size management."""
        # Remove oldest entries if cache is full
        if len(self.cache) >= self.max_size:
            oldest_key = min(self.access_times.keys(), key=self.access_times.get)
            del self.cache[oldest_key]
            del self.access_times[oldest_key]
        
        self.cache[key] = value
        self.access_times[key] = time.time()
```

### Asynchronous Operations

```python
class AsyncOperationManager:
    """Manages asynchronous operations with proper cancellation."""
    
    def __init__(self):
        self.active_operations = {}
        self.operation_results = {}
    
    async def run_async_operation(self, operation_id: str, operation_func, *args, **kwargs):
        """Run operation asynchronously with cancellation support."""
        if operation_id in self.active_operations:
            # Cancel existing operation
            self.active_operations[operation_id].cancel()
        
        # Create new operation
        task = asyncio.create_task(operation_func(*args, **kwargs))
        self.active_operations[operation_id] = task
        
        try:
            result = await task
            self.operation_results[operation_id] = result
            return result
        except asyncio.CancelledError:
            logger.info(f"Operation {operation_id} was cancelled")
            raise
        except Exception as e:
            logger.error(f"Operation {operation_id} failed: {e}")
            raise
        finally:
            if operation_id in self.active_operations:
                del self.active_operations[operation_id]
    
    def cancel_operation(self, operation_id: str):
        """Cancel active operation."""
        if operation_id in self.active_operations:
            self.active_operations[operation_id].cancel()
            return True
        return False

# Usage for email operations
class AsyncEmailPlugin(PluginBase):
    def __init__(self):
        super().__init__()
        self.async_manager = AsyncOperationManager()
    
    async def get_recent_emails_async(self, hours=2):
        """Asynchronous email retrieval."""
        return await self.async_manager.run_async_operation(
            'email_fetch',
            self._fetch_emails_impl,
            hours
        )
    
    async def _fetch_emails_impl(self, hours):
        """Implementation that can be cancelled."""
        # Use asyncio-compatible IMAP library
        async with aioimaplib.IMAP4_SSL(host=self.server) as imap:
            await imap.login(self.email, self.password)
            await imap.select('INBOX')
            
            # Check for cancellation periodically
            if asyncio.current_task().cancelled():
                raise asyncio.CancelledError()
            
            # Fetch emails
            search_criteria = self.build_search_criteria(hours)
            messages = await imap.search(search_criteria)
            
            emails = []
            for msg_id in messages[:10]:  # Limit for performance
                if asyncio.current_task().cancelled():
                    raise asyncio.CancelledError()
                
                email_data = await self.fetch_single_email(imap, msg_id)
                emails.append(email_data)
            
            return emails
```

---

## Learning Opportunities

### For Computer Science Students

This codebase provides excellent examples of:

#### 1. **Software Architecture Patterns**
- **MVC (Model-View-Controller)**: Clear separation between data, UI, and logic
- **Observer Pattern**: Plugin hooks system
- **Factory Pattern**: Plugin instantiation
- **Singleton Pattern**: Plugin manager
- **Strategy Pattern**: AI analysis with fallbacks
- **Command Pattern**: Undoable operations
- **State Machine**: Session state management

#### 2. **Advanced Python Concepts**
- **Abstract Base Classes**: Enforcing plugin interfaces
- **Dynamic Module Loading**: Runtime plugin discovery
- **Decorators**: PyQt signal/slot connections
- **Context Managers**: Resource management
- **Async/Await**: Non-blocking operations
- **Type Hints**: Better code documentation
- **Metaclasses**: Advanced OOP concepts

#### 3. **GUI Programming**
- **Event-driven architecture**: Responding to user interactions
- **Custom widget creation**: Specialized UI components
- **Animation systems**: Smooth visual feedback
- **Responsive layouts**: Adaptive UI design
- **Styling systems**: CSS-like appearance control

#### 4. **System Programming**
- **Process management**: Controlling other applications
- **File system operations**: Configuration and logging
- **Network programming**: HTTP requests and IMAP
- **Inter-process communication**: Shell script integration
- **Platform-specific APIs**: macOS integration

#### 5. **Software Engineering Practices**
- **Error handling strategies**: Graceful degradation
- **Logging and debugging**: Comprehensive diagnostics
- **Configuration management**: JSON-based settings
- **Plugin architecture**: Extensible design
- **Testing strategies**: Unit and integration testing
- **Documentation**: Code comments and external docs

### Suggested Improvements

1. **Add comprehensive unit tests**
   ```python
   import unittest
   from unittest.mock import Mock, patch
   
   class TestPluginSystem(unittest.TestCase):
       def setUp(self):
           self.plugin_manager = PluginManager()
       
       def test_plugin_loading(self):
           # Test plugin discovery and loading
           pass
       
       def test_hook_broadcasting(self):
           # Test plugin hook system
           pass
   ```

2. **Implement proper logging**
   ```python
   import logging
   from logging.handlers import RotatingFileHandler
   
   def setup_logging():
       logger = logging.getLogger('focus_utility')
       logger.setLevel(logging.INFO)
       
       # File handler with rotation
       file_handler = RotatingFileHandler(
           'focus_utility.log',
           maxBytes=10*1024*1024,  # 10MB
           backupCount=5
       )
       
       # Console handler
       console_handler = logging.StreamHandler()
       
       # Formatter
       formatter = logging.Formatter(
           '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
       )
       
       file_handler.setFormatter(formatter)
       console_handler.setFormatter(formatter)
       
       logger.addHandler(file_handler)
       logger.addHandler(console_handler)
   ```

3. **Add configuration validation**
   ```python
   from pydantic import BaseModel, validator
   from typing import Optional
   
   class PluginConfig(BaseModel):
       name: str
       version: str
       description: str
       main_file: str
       author: Optional[str] = None
       
       @validator('version')
       def validate_version(cls, v):
           # Semantic version validation
           import re
           if not re.match(r'^\d+\.\d+\.\d+$', v):
               raise ValueError('Version must be in format X.Y.Z')
           return v
   ```

4. **Implement async/await properly**
   ```python
   import asyncio
   import aiohttp
   
   class AsyncAIAnalyzer:
       async def analyze_goals_async(self, goals_text: str):
           async with aiohttp.ClientSession() as session:
               async with session.post(
                   self.api_url,
                   headers=self.headers,
                   json=self.build_payload(goals_text)
               ) as response:
                   if response.status == 200:
                       data = await response.json()
                       return self.parse_response(data)
                   else:
                       raise AIAnalysisError(f"API error: {response.status}")
   ```

### Real-World Applications

This architecture pattern is used in:
- **VSCode Extensions**: Similar plugin system
- **Sublime Text Packages**: Dynamic module loading
- **Eclipse Plugins**: Hook-based architecture
- **WordPress Plugins**: Action/filter system
- **Electron Apps**: Main/renderer process communication

### Career Relevance

Understanding this codebase prepares students for:
- **Desktop Application Development**: PyQt, Tkinter, Electron
- **Plugin Architecture Design**: Extensible software systems
- **System Integration**: OS-level programming
- **API Integration**: Third-party service integration
- **UI/UX Development**: Modern interface design
- **Software Architecture**: Large-scale system design

The combination of GUI programming, system integration, plugin architecture, and modern Python features makes this an excellent learning resource for understanding real-world software development practices.