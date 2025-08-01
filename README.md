# Focus Utility

A powerful macOS focus and productivity application that helps you stay concentrated by blocking distracting apps and websites while tracking your progress toward session goals.

## Features

- **Focus Modes**: Pre-configured modes for different types of work (Productivity, Creativity, Social Detox)
- **Smart App Blocking**: Automatically closes distracting applications
- **Website Blocking**: Optional website blocking with admin authentication
- **AI Goal Analysis**: Intelligent goal prioritization using Groq AI or local fallback
- **Progress Tracking**: Real-time session monitoring with goal checkboxes
- **Plugin System**: Extensible architecture for custom functionality
- **CLI Interface**: Command-line access for automation and scripting

## Quick Start

### GUI Mode (Traditional)
```bash
python3 focus_launcher.py
```

This launches the full graphical interface with focus mode selection, duration picker, goal setup, and progress tracking.

### CLI Mode
The CLI supports multiple modes of operation for flexibility and automation.

## CLI Usage

### Hybrid Mode (Recommended)
Skip the mode selector but keep other GUI dialogs:

```bash
# Specify mode - shows duration picker and goals dialog
python3 focusmode.py productivity

# Specify mode with goals - shows duration picker
python3 focusmode.py social --goals "Check emails;Quick review"

# Specify mode and duration - shows goals dialog  
python3 focusmode.py deep 90
```

### Full CLI Mode
Skip all GUI dialogs (requires all parameters):

```bash
# Fully automated session
python3 focusmode.py social 60 --no-gui

# With specific goals
python3 focusmode.py productivity 90 --goals "Code review;Bug fixes" --no-gui
```

### Additional CLI Options

```bash
# Skip countdown screen
python3 focusmode.py deep 120 --no-countdown

# Disable website blocking for this session
python3 focusmode.py productivity 60 --no-website-blocking

# List available focus modes
python3 focusmode.py --list

# Check mode status and details
python3 focusmode.py --status social

# Deactivate any active focus mode
python3 focusmode.py --deactivate
```

## Focus Modes

### Productivity Mode
- **Purpose**: Work and business applications
- **Blocks**: Social media, entertainment, gaming apps
- **Allows**: Office apps, development tools, communication tools

### Creativity Mode  
- **Purpose**: Design and creative work
- **Blocks**: Social media, productivity distractions
- **Allows**: Design tools, inspiration sites, creative applications

### Social Detox Mode
- **Purpose**: Digital wellness and deep focus
- **Blocks**: All social media, messaging, entertainment
- **Allows**: Essential work applications only

## Plugin System

The focus utility includes a powerful plugin system that allows you to extend functionality with custom features. 

📖 **[Complete Plugin Development Guide →](PLUGIN_DEVELOPMENT.md)**

### Available Plugins

- **Email Assistant**: Automatically converts important emails into focus session goals
- **Positive Feedback**: Provides encouraging messages during sessions

### Quick Plugin Installation

1. Create a new directory in `plugins/`
2. Add `manifest.json` with plugin metadata
3. Create `plugin.py` with your plugin class
4. The plugin will be automatically discovered and loaded

## Configuration

### API Keys
- **Groq AI**: Add your API key to `groq_api_key.txt` for AI goal analysis
- **Plugin Settings**: Configure individual plugins via `plugin_settings.json`

### Focus Mode Customization
Edit the mode files in the `modes/` directory to customize which apps and websites are blocked for each focus mode.

## File Structure

```
focus-utility/
├── focus_launcher.py          # Main GUI launcher
├── focusmode.py              # CLI interface
├── dialogs.py                # Dialog windows
├── widgets.py                # UI components
├── session.py                # Session management
├── plugin_system.py          # Plugin architecture
├── modes/                    # Focus mode definitions
├── plugins/                  # Plugin directory
├── CODE_EXPLANATION.md       # Technical documentation
└── PLUGIN_DEVELOPMENT.md     # Plugin development guide
```

## Requirements

- **macOS**: Required for app and website blocking functionality
- **Python 3.7+**: With PyQt5 for GUI components
- **Admin Access**: Required for website blocking (optional)

### Dependencies
```bash
pip install PyQt5 requests
```

## Examples

### Quick Productivity Session
```bash
# Start 90-minute productivity session with specific goals
python3 focusmode.py productivity 90 --goals "Finish quarterly report;Review team PRs;Update project docs"
```

### Social Media Break
```bash
# 30-minute social detox with no distractions
python3 focusmode.py social 30 --no-gui
```

### Creative Deep Work
```bash
# 2-hour creative session with countdown
python3 focusmode.py creativity 120
```

## Advanced Usage

### Automation Scripts
```bash
#!/bin/bash
# Morning focus routine
python3 focusmode.py productivity 90 --goals "Daily standup prep;Priority inbox review;Sprint planning" --no-gui

# Afternoon deep work
python3 focusmode.py deep 120 --no-countdown --no-gui
```

### Plugin Development
Create custom plugins to integrate with your workflow:

- **Calendar Integration**: Sync with calendar events
- **Task Management**: Import from Todoist, Asana, etc.
- **Wellness Tracking**: Monitor break times and posture
- **Team Collaboration**: Share focus sessions with teammates

See the [Plugin Development Guide](PLUGIN_DEVELOPMENT.md) for complete documentation and examples.

## Troubleshooting

### Common Issues

**"Plugin not loaded"**: Check plugin syntax and manifest.json format
**"Password required"**: Website blocking needs admin authentication
**"No modes found"**: Ensure mode files exist in the `modes/` directory

### Debug Mode
Run with verbose output for troubleshooting:
```bash
python3 focusmode.py productivity --debug
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with existing plugins
5. Submit a pull request

## License

This project is open source. See LICENSE file for details.

---

**💡 Pro Tip**: Use the hybrid CLI mode (`python3 focusmode.py [mode]`) for the perfect balance of automation and control - it skips the mode selection but keeps the helpful duration and goals dialogs.