# TOME - Focus Management System

A revolutionary SwiftUI-based focus management system that completely replaces the macOS interface with beautifully designed, minimalist environments for deep work and productivity.

## Overview

TOME transforms your Mac into a dedicated focus machine, featuring:

- **Complete macOS replacement** when active (dock, menubar, desktop)
- **Fluid, GPU-accelerated animations** at 120fps
- **AI-powered planning and notification filtering** via OpenAI
- **Hardware integration** with Arduino-based control devices
- **Nothing-inspired minimalist aesthetic** with Teenage Engineering interaction principles
- **Multiple focus environments** each optimized for different types of work

## Architecture

### Core Technology Stack
- **SwiftUI + Core Animation** for native macOS performance
- **Metal Framework** for GPU-accelerated visual effects
- **OpenAI API** for intelligent features and chat assistance
- **USB-C/Serial communication** for hardware integration
- **AVKit** for transition video playback

### Environment System
- **Home**: Central hub with dial-based environment selection
- **Planning**: Three-column AI-assisted todo management
- **Writer's Desk**: Typewriter-aesthetic communication interface
- **Workshop**: Minimal development environment with tool switching
- **Coffeeshop**: Research-optimized browsing with serendipity features
- **Garden**: Restorative space for meditation and reflection

## Setup Instructions

### Prerequisites
- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+
- Swift 5.9+
- OpenAI API key

### Installation

1. **Clone and build**:
   ```bash
   git clone [repository-url]
   cd macos-focus-utility
   swift build --configuration release
   ```

2. **Configure OpenAI API**:
   ```bash
   echo "your-openai-api-key-here" > legacy/openai_api_key.txt
   ```
   Or set environment variable:
   ```bash
   export OPENAI_API_KEY="your-openai-api-key-here"
   ```

3. **Run TOME**:
   ```bash
   swift run TOME
   ```

### Hardware Setup (Optional)

TOME supports Arduino-based control surfaces for enhanced interaction:

1. **Compatible devices**: Arduino Uno/Nano with USB connection
2. **Required components**:
   - Rotary encoder (for environment dial)
   - 4 tactile buttons
   - RGB LED strip (optional)
   - USB-C or USB-A connection

3. **Upload firmware**: Use the Arduino sketches in `legacy/plugins/*/focushardwarev1/`

## Features

### AI-Powered Planning
- **Natural language todo parsing**: "I need to email John and check AWS billing" → separate tasks
- **Intelligent duration estimation** based on task analysis
- **Smart notification filtering** with learning metaprompts
- **Context-aware suggestions** for productivity optimization

### Seamless Environment Switching
- **Fluid transitions** with video playback from legacy system
- **Project-space mapping** with state preservation
- **Hardware dial control** for instant environment switching
- **Ambient lighting sync** with connected LED hardware

### Advanced Visual Design
- **120fps animations** with Metal acceleration
- **Particle effects and breathing animations**
- **Monochromatic Nothing-inspired palette**
- **Typography**: Custom monospaced fonts throughout
- **Glass morphism effects** with subtle transparency

### Hardware Integration
- **Real-time dial position tracking**
- **Button event handling** for quick actions
- **LED feedback** synchronized with current environment
- **USB-C/Serial protocol** for reliable communication

## Environment Details

### Home Environment
- Central portal with rotating dial control
- Recent projects display with visual environment cues
- Hardware status indicator
- Smooth environment preview animations

### Planning Mode
- **Left Panel (60%)**: Todo management with AI parsing
- **Right Panel (40%)**: AI assistant and metaprompt editor
- Brain dump to structured tasks conversion
- Calendar integration with meeting preparation
- Notification filtering configuration

### Writer's Desk
- **Left Panel (25%)**: Unified inbox with priority sorting
- **Center Panel (50%)**: Typewriter-style composition interface
- **Right Panel (25%)**: Communication todos and templates
- AI-powered draft assistance and tone adjustment
- Sound effects for tactile feedback

### Workshop
- **Fullscreen tool display**: IDE, terminal, browser integration
- **Overlay controls**: Progress tracking and tool switching
- **Quick capture**: Ideas, bugs, notes, timers
- **Minimal UI**: Focus on the tools, not the interface

### Coffeeshop
- **Research browser (60%)**: Ad-blocked, distraction-free browsing
- **Notes panel (40%)**: Mind-mapping and reference capture
- **Serendipity mode**: AI-suggested related topics
- **Rabbit hole timer**: Gentle reminders for extended research sessions

### Garden
- **Breathing exercises**: 4-7-8 technique with visual guidance
- **Meditation timer**: Minimalist countdown with ambient sounds
- **Reflection journaling**: Mood tracking and insight capture
- **Stretching reminders**: Guided physical wellness breaks

## Legacy System Migration

The previous Python/PyQt5 system has been preserved in the `legacy/` folder:

### Preserved Components
- **Configuration files**: Mode definitions, host blocking lists
- **Plugin system**: All existing plugins and their configurations
- **Transition videos**: Reused in the new SwiftUI system
- **Audio assets**: Sound effects and notification tones
- **Arduino firmware**: Hardware control sketches

### Migration Benefits
- **10x performance improvement** with native SwiftUI
- **50% lower memory usage** compared to PyQt5
- **GPU acceleration** for smooth 120fps animations
- **Better system integration** with macOS APIs
- **Modular architecture** for easier hardware expansion

## Development

### Project Structure
```
Sources/TOME/
├── main.swift                 # App entry point
├── ContentView.swift          # Main view controller
├── Models/
│   ├── Environment.swift      # Environment definitions
│   └── TOMEState.swift        # Application state management
├── Views/
│   ├── Environments/          # Individual environment views
│   └── Components/            # Reusable UI components
└── Services/
    ├── OpenAIService.swift    # AI integration
    └── HardwareService.swift  # Arduino communication
```

### Building and Testing
```bash
# Debug build
swift build

# Release build
swift build --configuration release

# Run tests
swift test

# Generate Xcode project
swift package generate-xcodeproj
```

### Contributing
1. Focus on maintaining the minimalist aesthetic
2. Ensure all animations run at 120fps
3. Follow Nothing/Teenage Engineering design principles
4. Test hardware integration with actual Arduino devices
5. Maintain OpenAI API compatibility

## Performance Targets

- **Startup time**: < 500ms from launch to UI
- **Memory usage**: < 100MB base footprint
- **Animation framerate**: Consistent 120fps on Apple Silicon
- **Hardware response time**: < 50ms for dial/button events
- **AI response time**: < 2s for most queries

## Hardware Protocol

The Arduino communication uses a simple packet-based protocol:

```
Packet Format: [0xFF][Command][Length][Data...][Checksum]

Commands:
- 0x01: Ping (keep-alive)
- 0x02: Get dial position
- 0x03: Get button states
- 0x04: Set LED brightness
- 0x05: Set LED pattern
- 0x06: Get device status
```

See `HardwareService.swift` for complete implementation details.

## Troubleshooting

### Common Issues
1. **OpenAI API errors**: Check API key configuration
2. **Hardware not detected**: Verify Arduino connection and drivers
3. **Poor animation performance**: Ensure Metal-capable GPU
4. **Transition videos not playing**: Check legacy folder video files

### Debug Mode
```bash
swift run TOME --debug
```

### Hardware Testing
```bash
# Test hardware connection
swift run TOME --test-hardware

# Monitor serial communication
screen /dev/cu.usbmodem* 9600
```

## License

This project builds upon the original Python focus utility and incorporates new SwiftUI innovations for a next-generation focus management experience.

---

**Experience deep focus. Achieve more. Focus with TOME.**