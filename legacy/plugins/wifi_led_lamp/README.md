# WiFi LED Lamp Plugin

A comprehensive plugin that controls WiFi-connected ARGB LED lamps to provide ambient lighting that matches your focus mode. The lamp automatically adjusts colors, animations, and white light based on your current focus session.

## Features

- 🎨 **Mode-specific lighting**: Different colors and animations for each focus mode
- 🌈 **Smooth ARGB animations**: Beautiful color transitions that stay close to the primary color
- 💡 **Dual-zone lighting**: Separate front (white) and back (colored) lighting zones
- 🌡️ **Adjustable white temperature**: From warm 1800K to cool 9000K lighting
- 🎛️ **Movement control**: Adjustable animation speed and color variation
- 📱 **Auto-discovery**: Automatically finds lamps on your network
- 🔧 **User-friendly setup**: No coding required after initial upload

## Hardware Requirements

- ESP8266 development board (NodeMCU, Wemos D1 Mini, etc.)
- WS2812B LED strip with 30 LEDs
- 5V power supply (capacity depends on LED count)
- Jumper wires
- Optional: enclosure/lamp housing

## Wiring

```
ESP8266 GPIO5 → LED Strip Data Pin
ESP8266 GND   → LED Strip GND
5V Supply+    → LED Strip VCC
5V Supply-    → LED Strip GND & ESP8266 GND
```

**Important**: Use external 5V power for the LED strip. The ESP8266 runs on 3.3V but can usually drive the data signal directly.

## Software Setup

### Step 1: Arduino IDE Preparation

1. **Install Arduino IDE** (if not already installed)
2. **Add ESP8266 Board Support**:
   - Go to File → Preferences
   - Add this URL to "Additional Board Manager URLs":
     ```
     https://arduino.esp8266.com/stable/package_esp8266com_index.json
     ```
   - Go to Tools → Board → Boards Manager
   - Search for "ESP8266" and install the ESP8266 package

3. **Install Required Libraries**:
   - Go to Tools → Manage Libraries
   - Install these libraries:
     - `FastLED` by Daniel Garcia
     - `ArduinoJson` by Benoit Blanchon
     - `WiFiManager` by tzapu

### Step 2: Upload Arduino Sketch

1. **Open the sketch**: Load `arduino_sketch/wifi_led_lamp.ino` in Arduino IDE
2. **Select your board**: 
   - Tools → Board → ESP8266 Boards → (select your board, e.g., "NodeMCU 1.0")
3. **Select the port**: Tools → Port → (select the COM port for your ESP8266)
4. **Upload**: Click the upload button (→) or Ctrl+U

### Step 3: WiFi Configuration

1. **First boot**: After uploading, the ESP8266 will create a WiFi hotspot
2. **Connect to hotspot**: 
   - On your phone/computer, connect to the WiFi network named `FocusLamp-Setup`
   - A configuration page should open automatically (or go to 192.168.4.1)
3. **Configure WiFi**:
   - Select your home WiFi network from the list
   - Enter your WiFi password
   - Click "Save"
4. **Restart**: The ESP8266 will restart and connect to your WiFi network

### Step 4: Plugin Setup

1. **Enable plugin**: In Focus Utility, go to Settings → Plugins and enable "WiFi LED Lamp"
2. **Open settings**: Click the settings/gear icon next to the plugin
3. **Discover devices**: Click "🔍 Scan for LED Lamps" to find your device
4. **Connect**: Select your lamp and click "Connect to Selected"
5. **Test**: Click "💡 Test Lamp" to verify the connection works
6. **Configure modes**: Customize the lighting settings for each focus mode

## Configuration Options

### Per-Mode Settings

Each focus mode (productivity, creativity, social_media_detox, custom modes) has these settings:

#### Primary Color
- The main color displayed on the back LEDs
- Animations will create variations around this color
- Click the color button to choose using a color picker

#### Movement (0-100%)
- **0%**: Static color, no animation
- **50%**: Moderate color variations and animation speed  
- **100%**: Fast animations with more color variation
- Colors always stay close to the primary color

#### Front White Light
- **Enabled**: Front 18 LEDs show static white light
- **Disabled**: Front LEDs show the same animated color as back LEDs

#### White Temperature (when front white is enabled)
- **1800K**: Warm candlelight color
- **2200K**: Warm incandescent
- **2700K**: Soft white (living room lighting)
- **3000K**: Warm white
- **4000K**: Neutral white (office lighting)
- **5000K**: Daylight white
- **6500K**: Cool daylight
- **9000K**: Blue-tinted cool light

### Default Configurations

- **Productivity Mode**: Light blue, low movement (20%), front white at 4000K
- **Creativity Mode**: Deep purple, high movement (80%), no front white
- **Social Media Detox Mode**: Orange, medium movement (50%), front white at 2700K
- **Custom Modes**: Neutral gray, medium movement (30%), no front white

## LED Zones

The 30-LED strip is divided into two zones:

- **Back Zone** (LEDs 0-11): Always shows animated primary color
- **Front Zone** (LEDs 12-29): Shows animated color OR static white light

## Animations

The plugin creates smooth, organic-looking animations by:
- Slowly shifting hue around the primary color
- Varying saturation and brightness across LEDs
- Using position-based phase offsets for wave-like effects
- Keeping all variations close to the chosen primary color

## Transitions

Beautiful transitions occur when:
- **Session starts**: Spiral-in animation with the new mode's color
- **Session ends**: Smooth fade to black
- **Mode changes**: Fade out, then spiral in with new color
- **Testing**: Rainbow sweep animation

## Troubleshooting

### Device Not Found During Discovery
- Ensure ESP8266 and computer are on the same WiFi network
- Check that the ESP8266 is powered and running (watch serial monitor)
- Verify the Arduino sketch uploaded successfully
- Try manually accessing `http://[ESP_IP_ADDRESS]/discover` in a browser

### WiFi Connection Issues
- Reset WiFi settings by uncommenting `wifiManager.resetSettings();` in the Arduino sketch
- Re-upload sketch and reconfigure WiFi
- Check WiFi credentials are correct
- Ensure 2.4GHz WiFi (ESP8266 doesn't support 5GHz)

### LEDs Not Working
- Check wiring connections
- Verify 5V power supply is adequate (each LED can draw ~60mA at full brightness)
- Confirm LED strip is WS2812B compatible
- Check GPIO pin assignment (default is GPIO5)

### Connection Timeouts
- Increase timeout values in plugin if network is slow
- Check firewall settings aren't blocking connections
- Verify ESP8266 hasn't crashed (check serial monitor)

### Animation Issues
- Lower movement values if animations are too fast/chaotic
- Check FastLED library is properly installed
- Verify NUM_LEDS matches your actual LED count

## Technical Details

### Communication Protocol
- HTTP REST API over WiFi
- JSON message format
- Endpoints:
  - `GET /discover` - Device discovery
  - `GET /status` - Current status
  - `POST /control` - Send commands

### Performance
- Network discovery scans 254 IPs in parallel with threading
- Animations run at ~20-50 FPS depending on movement setting
- Low network overhead (commands sent only on state changes)

### Security
- No authentication (intended for local network use)
- CORS headers for web compatibility
- Input validation on ESP8266 side

## Customization

### Adding More LEDs
1. Change `NUM_LEDS` in the Arduino sketch
2. Adjust `BACK_COUNT` and `FRONT_COUNT` for your zones
3. Ensure adequate power supply

### Different LED Types
- Modify FastLED configuration line for your LED type
- Common types: WS2812B, WS2811, SK6812, APA102

### Custom Animations
- Modify `getAnimatedColor()` function in Arduino sketch
- Add new animation patterns in `updateAnimation()`

## Files Structure

```
plugins/wifi_led_lamp/
├── manifest.json              # Plugin metadata
├── plugin.py                  # Main plugin code
├── README.md                  # This documentation
├── arduino_sketch/
│   └── wifi_led_lamp.ino     # ESP8266 firmware
└── lamp_settings.json        # Auto-generated settings file
```

## Version History

- **v1.0.0**: Initial release with full functionality

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify all wiring and software setup steps
3. Check the Arduino IDE serial monitor for ESP8266 debug output
4. Ensure all required libraries are installed and up to date

The plugin is designed to be user-friendly, but LED projects can have many variables. Most issues are related to wiring, power supply, or WiFi connectivity.