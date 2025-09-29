# TOME Installation Guide

## Quick Start

1. **Install dependencies**:
   ```bash
   # Ensure you have Xcode 15+ installed
   xcode-select --install
   ```

2. **Get OpenAI API key**:
   - Visit https://platform.openai.com/api-keys
   - Create new key
   - Save to file: `echo "your-key-here" > legacy/openai_api_key.txt`

3. **Build and run**:
   ```bash
   swift build --configuration release
   swift run TOME
   ```

4. **Grant permissions**:
   - Allow accessibility access for app control
   - Grant screen recording for fullscreen takeover

## Hardware Setup (Optional)

### Arduino Firmware
1. Open Arduino IDE
2. Load sketch from `legacy/plugins/control_surface/focushardwarev1/`
3. Select your Arduino board and port
4. Upload firmware

### Wiring Diagram
```
Arduino Uno:
- Pin 2: Rotary encoder A
- Pin 3: Rotary encoder B
- Pin 4-7: Buttons 1-4
- Pin 9: LED strip data (optional)
- GND: Common ground
- 5V: Power (if needed)
```

## Transition from Legacy System

The old Python system remains in `legacy/` for reference. To fully transition:

1. **Export settings**: The new system automatically reads from `legacy/plugin_settings.json`
2. **Copy API keys**: Move `gemini_api_key.txt` if migrating from Gemini to OpenAI
3. **Preserve videos**: Transition videos are automatically detected in `legacy/videos/`

## First Launch

1. **Environment selection**: Use mouse/trackpad or connected hardware dial
2. **Planning setup**: Configure your notification metaprompt
3. **AI chat**: Test OpenAI integration in Planning mode
4. **Hardware calibration**: If connected, test dial and buttons

## Troubleshooting

### Build Issues
```bash
# Clear build cache
swift package reset
swift build --configuration release
```

### Permission Errors
- System Preferences → Security & Privacy → Accessibility → Add TOME
- System Preferences → Security & Privacy → Screen Recording → Add TOME

### Hardware Not Detected
```bash
# List USB devices
system_profiler SPUSBDataType | grep -A5 Arduino

# Check serial ports
ls /dev/cu.*
```

## Performance Optimization

For best experience:
- Use Apple Silicon Mac (M1/M2/M3)
- Enable ProMotion displays (120Hz)
- Close other intensive applications
- Ensure adequate free RAM (4GB+)

## Next Steps

1. **Customize environments**: Modify colors and layouts in source code
2. **Add integrations**: Extend OpenAI prompts for your workflow
3. **Build hardware**: Create custom control surface using Arduino
4. **Share feedback**: Report issues and suggest improvements