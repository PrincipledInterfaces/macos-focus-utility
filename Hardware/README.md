# TOME Hardware Controller

ESP8266-based hardware interface for TOME Focus Utility.

## Hardware Requirements

- ESP8266 Development Board (NodeMCU, Wemos D1 Mini, etc.)
- Rotary Encoder with integrated push button (KY-040 or similar)
- 3x Tactile Push Buttons
- Optional: WS2812B/NeoPixel ARGB LED strip (for future implementation)

## Wiring Diagram

### Rotary Encoder
- CLK (A) → D5 (GPIO14)
- DT (B) → D6 (GPIO12)
- SW (Button) → D7 (GPIO13)
- + (VCC) → 3.3V
- GND → GND

### Buttons
- Button 1 (AI Chat) → D1 (GPIO5)
- Button 2 (Home) → D2 (GPIO4)
- Button 3 (Phone Eject) → D3 (GPIO0)

All buttons should be wired between the pin and GND (active LOW with internal pull-up).

### LED Strip (Future)
- Data → D4 (GPIO2)
- VCC → 5V (external power recommended for long strips)
- GND → GND

## Installation

### Arduino IDE Setup

1. Install Arduino IDE (version 2.0+ recommended)
2. Add ESP8266 board support:
   - Go to File → Preferences
   - Add to "Additional Board Manager URLs":
     `http://arduino.esp8266.com/stable/package_esp8266com_index.json`
   - Go to Tools → Board → Board Manager
   - Search for "esp8266" and install

3. Select your board:
   - Tools → Board → ESP8266 Boards → Select your board (e.g., "NodeMCU 1.0")
   - Tools → Port → Select the appropriate serial port

4. Upload the sketch:
   - Open `ESP8266_TOME_Controller.ino`
   - Click Upload

### PlatformIO Setup (Alternative)

If using PlatformIO, create a `platformio.ini` file:

```ini
[env:nodemcuv2]
platform = espressif8266
board = nodemcuv2
framework = arduino
monitor_speed = 115200
```

## Functionality

### Rotary Encoder
- **Rotation**: Navigate between mode cards (clockwise = right, counter-clockwise = left)
- **Click**: Select/confirm mode
- **Contexts**:
  - Home screen: Select between environments (Planning, Writer's Desk, Workshop, Coffeeshop, Garden)
  - Workshop mode: Select between IDE and Terminal

### Buttons
- **Button 1 (AI Chat)**: Opens the AI assistant window (equivalent to ⌘A or clicking the brain icon)
- **Button 2 (Home)**: Returns to home screen (equivalent to ESC or clicking the home button)
- **Button 3 (Phone Eject)**: Placeholder for future phone integration feature

## Communication Protocol

The ESP8266 communicates with the macOS app via USB serial at 115200 baud using a binary packet protocol:

### Packet Structure
```
[START_BYTE] [COMMAND/RESPONSE] [DATA_LENGTH] [DATA...] [CHECKSUM]
```

- START_BYTE: 0xFF
- CHECKSUM: XOR of all bytes except START_BYTE

### Commands (Host → ESP8266)
- `0x01` - PING: Test connection
- `0x02` - GET_ENCODER: Request encoder position
- `0x03` - GET_BUTTONS: Request button states
- `0x04` - SET_LED: Set LED brightness/pattern (future)
- `0x05` - GET_EVENTS: Retrieve queued events

### Responses (ESP8266 → Host)
- `0x81` - PONG: Connection acknowledgment
- `0x82` - ENCODER: Encoder position data
- `0x83` - BUTTONS: Button state data
- `0x84` - LED_ACK: LED command acknowledgment
- `0x85` - EVENTS: Event queue data

### Events
Events are queued and sent when requested:
- `0x01` - ENCODER_CW: Clockwise rotation
- `0x02` - ENCODER_CCW: Counter-clockwise rotation
- `0x03` - ENCODER_CLICK: Encoder button pressed
- `0x04` - BUTTON_AI: AI chat button pressed
- `0x05` - BUTTON_HOME: Home button pressed
- `0x06` - BUTTON_EJECT: Phone eject button pressed

## Troubleshooting

### Device Not Connecting
1. Check USB cable (must support data, not just power)
2. Install CH340/CP2102 drivers if needed
3. Verify the correct port is selected
4. Check baud rate is set to 115200

### Encoder Not Working
1. Verify wiring connections
2. Check that CLK is connected to D5, DT to D6, SW to D7
3. Ensure encoder has common ground with ESP8266
4. Try swapping CLK and DT pins if direction is reversed

### Buttons Not Responding
1. Verify pull-up resistors are enabled (internal pull-ups are used by default)
2. Check button wiring (should connect pin to GND when pressed)
3. Adjust `debounceDelay` in code if buttons are bouncing

## Future Enhancements

- ARGB LED strip integration for visual feedback
- Haptic feedback via small vibration motor
- Additional analog inputs for sliders/potentiometers
- WiFi-based communication option
- Battery operation with sleep modes
