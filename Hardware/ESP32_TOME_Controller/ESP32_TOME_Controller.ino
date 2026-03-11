/*
 * TOME Hardware Controller - ESP32
 *
 * Hardware Setup:
 * - Rotary Encoder: CLK -> 22, DT -> 21, SW -> 19
 * - Button 1 (AI Chat): 5
 * - Button 2 (Home): 16
 * - Button 3 (Phone Eject): 17
 * - Phone Charger Detection: 32 (3V input)
 * - Stepper Motor: STEP -> 27, DIR -> 14, EN -> 26
 * - ARGB LED Strip: 18 (23 LEDs)
 *
 * Communication: Serial over USB at 115200 baud
 * Protocol: Binary packet-based with checksums
 */

#include <Arduino.h>
#include <FastLED.h>

// Pin Definitions
#define ENCODER_CLK 22
#define ENCODER_DT  21
#define ENCODER_SW  19
#define BUTTON_AI   5
#define BUTTON_HOME 16
#define BUTTON_EJECT 17
#define PHONE_DETECT 32
#define MOTOR_STEP  27
#define MOTOR_DIR   14
#define MOTOR_EN    26
#define LED_PIN     18
#define NUM_LEDS    23

// Motor Configuration
//#define STEPS_FULL_TRAVEL 3200  // Steps for full up/down travel
#define STEPS_FULL_TRAVEL 0  // Steps for full up/down travel
int MOTOR_SPEED = 70;  // Microseconds between steps (adjustable)

// Test mode - set to true to bypass phone lock requirement
#define TEST_MODE true  // Set to false for production

// Phone bypass - set to true to assume phone is always present
#define PHONE_BYPASS true  // Set to false for production

// Debug mode - enable serial debugging
#define DEBUG_MODE false  // Set to false to disable debug output

// Phone Lift States
enum LiftState {
  LIFT_INIT,          // Initial startup
  LIFT_MOVING_UP,     // Moving to top position
  LIFT_WAITING_PHONE, // At top, waiting for phone
  LIFT_MOVING_DOWN,   // Moving phone down
  LIFT_PHONE_LOCKED,  // Phone locked in, normal operation
  LIFT_EJECTING       // Ejecting phone
};

// Environment modes
enum EnvironmentMode {
  ENV_HOME = 0,
  ENV_PLANNING = 1,
  ENV_WRITERDESK = 2,
  ENV_WORKSHOP = 3,
  ENV_COFFEESHOP = 4,
  ENV_GARDEN = 5
};

// Environment color definitions (hardcoded theme colors)
const CRGB ENV_COLORS[] = {
  CRGB(255, 255, 255),  // HOME - White
  CRGB(0, 0, 255),      // PLANNING - Blue
  CRGB(0, 255, 0),      // WRITERDESK - Green
  CRGB(128, 0, 128),    // WORKSHOP - Purple
  CRGB(255, 165, 0),    // COFFEESHOP - Orange
  CRGB(0, 255, 0)       // GARDEN - Green
};

// Protocol Constants
#define START_BYTE 0xFF

// Commands (from host)
enum Command {
  CMD_PING = 0x01,
  CMD_GET_ENCODER = 0x02,
  CMD_GET_BUTTONS = 0x03,
  CMD_SET_LED = 0x04,
  CMD_GET_EVENTS = 0x05,
  CMD_GET_PHONE_STATUS = 0x06,
  CMD_SET_ENVIRONMENT = 0x07,  // Changed from SET_ENVIRONMENT_COLOR
  CMD_EJECT_PHONE = 0x08,
  CMD_SET_MOTOR_SPEED = 0x09
};

// Responses (to host)
enum Response {
  RESP_PONG = 0x81,
  RESP_ENCODER = 0x82,
  RESP_BUTTONS = 0x83,
  RESP_LED_ACK = 0x84,
  RESP_EVENTS = 0x85,
  RESP_PHONE_STATUS = 0x86,
  RESP_ENV_ACK = 0x87,  // Changed from ENV_COLOR_ACK
  RESP_EJECT_ACK = 0x88,
  RESP_MOTOR_SPEED_ACK = 0x89
};

// Event Types
enum EventType {
  EVENT_ENCODER_CW = 0x01,      // Clockwise rotation
  EVENT_ENCODER_CCW = 0x02,     // Counter-clockwise rotation
  EVENT_ENCODER_CLICK = 0x03,   // Encoder button pressed
  EVENT_BUTTON_AI = 0x04,       // AI chat button pressed
  EVENT_BUTTON_HOME = 0x05,     // Home button pressed
  EVENT_BUTTON_EJECT = 0x06,    // Phone eject button pressed
  EVENT_PHONE_PLACED = 0x07,    // Phone placed on charger
  EVENT_PHONE_REMOVED = 0x08,   // Phone removed from charger
  EVENT_PHONE_LOCKED = 0x09     // Phone locked in position
};

// Encoder state
volatile int encoderPosition = 0;
volatile int lastEncoderCLK = HIGH;
volatile bool encoderClicked = false;
volatile bool encoderChanged = false;
volatile int encoderDirection = 0; // 1 for CW, -1 for CCW
volatile unsigned long lastEncoderTime = 0;

// Button states
bool lastButtonAI = HIGH;
bool lastButtonHome = HIGH;
bool lastButtonEject = HIGH;
bool lastEncoderButton = HIGH;

// Phone charger state
bool phonePresent = false;
bool lastPhonePresent = false;
bool phoneChargerReady = false;
unsigned long phoneDebounceTime = 0;
const unsigned long phoneDebounceDelay = 200;

// Lift state
LiftState liftState = LIFT_INIT;
int currentLiftPosition = 0;  // Track current position in steps

// LED state
CRGB leds[NUM_LEDS];
EnvironmentMode currentEnvironment = ENV_HOME;  // Default to home
unsigned long ledUpdateTime = 0;
int lastEncoderPos = 0;

// Button animation state
bool buttonPressedAnimation = false;
unsigned long buttonPressTime = 0;
uint8_t shockwaveRadius = 0;

// Event queue
#define MAX_EVENTS 32
struct Event {
  uint8_t type;
  int16_t value;
};
Event eventQueue[MAX_EVENTS];
uint8_t eventQueueHead = 0;
uint8_t eventQueueTail = 0;

// Debouncing - each button gets its own timer
unsigned long lastDebounceTimeEncoder = 0;
unsigned long lastDebounceTimeAI = 0;
unsigned long lastDebounceTimeHome = 0;
unsigned long lastDebounceTimeEject = 0;
const unsigned long debounceDelay = 50;

// Forward declarations
void IRAM_ATTR handleEncoder();
void updateLEDs();
void updateLift();
void moveLiftUp();
void moveLiftDown();
void stepMotor(int steps, bool up);
bool processCommand();

void setup() {
  Serial.begin(115200);
  while (!Serial) {
    ; // Wait for serial port to connect
  }

  // Configure encoder pins
  pinMode(ENCODER_CLK, INPUT_PULLUP);
  pinMode(ENCODER_DT, INPUT_PULLUP);
  pinMode(ENCODER_SW, INPUT_PULLUP);

  // Configure button pins
  pinMode(BUTTON_AI, INPUT_PULLUP);
  pinMode(BUTTON_HOME, INPUT_PULLUP);
  pinMode(BUTTON_EJECT, INPUT_PULLUP);

  // Configure phone detection pin
  pinMode(PHONE_DETECT, INPUT);

  // Configure motor pins
  pinMode(MOTOR_STEP, OUTPUT);
  pinMode(MOTOR_DIR, OUTPUT);
  pinMode(MOTOR_EN, OUTPUT);
  digitalWrite(MOTOR_EN, HIGH);  // Disable motor initially
  digitalWrite(MOTOR_STEP, LOW);
  digitalWrite(MOTOR_DIR, LOW);

  // Initialize LED strip
  FastLED.addLeds<WS2812B, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(255);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();

  // Attach interrupt for encoder
  attachInterrupt(digitalPinToInterrupt(ENCODER_CLK), handleEncoder, CHANGE);

  // Initialize encoder state
  lastEncoderCLK = digitalRead(ENCODER_CLK);

  // Wait for phone charger to initialize (2.5 seconds as per phone charger code)
  delay(2500);
  phoneChargerReady = true;

  // Initialize lift - move to top position
  liftState = LIFT_MOVING_UP;
  moveLiftUp();
  liftState = LIFT_WAITING_PHONE;

  // Quick startup LED animation (non-blocking)
  fill_solid(leds, NUM_LEDS, CRGB::Blue);
  FastLED.show();
  delay(200);
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();
}

void loop() {
  // Process encoder changes from ISR
  if (encoderChanged) {
    encoderChanged = false;
    if (encoderDirection == 1) {
      queueEvent(EVENT_ENCODER_CW, encoderPosition);
    } else if (encoderDirection == -1) {
      queueEvent(EVENT_ENCODER_CCW, encoderPosition);
    }
  }

  // Check for incoming commands (process multiple to prevent backup)
  while (Serial.available() >= 4) {
    if (!processCommand()) {
      break;  // Stop if we can't process (incomplete packet)
    }
  }

  // Always check buttons
  checkButtons();

  // Check phone charger status
  checkPhoneStatus();

  // Update lift state machine
  updateLift();

  // Update LED animations
  updateLEDs();

  // No delay - run as fast as possible for maximum responsiveness
}

void IRAM_ATTR handleEncoder() {
  // Read the current state
  int clkState = digitalRead(ENCODER_CLK);
  int dtState = digitalRead(ENCODER_DT);

  // Only process on CLK change
  if (clkState != lastEncoderCLK) {
    // Debounce - ignore changes faster than 5ms
    unsigned long currentTime = millis();
    if (currentTime - lastEncoderTime < 5) {
      lastEncoderCLK = clkState;
      return;
    }

    // Only count on falling edge
    if (clkState == LOW) {
      // Determine direction based on DT state
      if (dtState == HIGH) {
        // Clockwise
        encoderPosition++;
        encoderDirection = 1;
        encoderChanged = true;
      } else {
        // Counter-clockwise
        encoderPosition--;
        encoderDirection = -1;
        encoderChanged = true;
      }
      lastEncoderTime = currentTime;
    }

    lastEncoderCLK = clkState;
  }
}

void checkPhoneStatus() {
  if (!phoneChargerReady) return;

  // If phone bypass is enabled, always assume phone is present
  if (PHONE_BYPASS) {
    if (!phonePresent) {
      phonePresent = true;
      queueEvent(EVENT_PHONE_PLACED, 1);
    }
    return;
  }

  unsigned long currentTime = millis();
  bool phoneDetected = digitalRead(PHONE_DETECT) == HIGH;

  // Debounce phone detection
  if (phoneDetected != lastPhonePresent) {
    if (currentTime - phoneDebounceTime > phoneDebounceDelay) {
      phonePresent = phoneDetected;
      phoneDebounceTime = currentTime;

      if (phonePresent && !lastPhonePresent) {
        queueEvent(EVENT_PHONE_PLACED, 1);
      } else if (!phonePresent && lastPhonePresent) {
        queueEvent(EVENT_PHONE_REMOVED, 1);
      }
    }
  }
  lastPhonePresent = phonePresent;
}

void updateLift() {
  switch (liftState) {
    case LIFT_WAITING_PHONE:
      // Check if phone was placed
      if (phonePresent) {
        liftState = LIFT_MOVING_DOWN;
        moveLiftDown();
        liftState = LIFT_PHONE_LOCKED;
        queueEvent(EVENT_PHONE_LOCKED, 1);
      }
      break;

    case LIFT_PHONE_LOCKED:
      // Check if phone was removed unexpectedly
      if (!phonePresent) {
        liftState = LIFT_MOVING_UP;
        moveLiftUp();
        liftState = LIFT_WAITING_PHONE;
      }
      break;

    case LIFT_EJECTING:
      moveLiftUp();
      liftState = LIFT_WAITING_PHONE;
      break;

    default:
      break;
  }
}

void moveLiftUp() {
  stepMotor(STEPS_FULL_TRAVEL, true);
  currentLiftPosition = STEPS_FULL_TRAVEL;
}

void moveLiftDown() {
  stepMotor(STEPS_FULL_TRAVEL, false);
  currentLiftPosition = 0;
}

void stepMotor(int steps, bool up) {
  digitalWrite(MOTOR_EN, LOW);  // Enable motor
  digitalWrite(MOTOR_DIR, up ? LOW : HIGH);

  for (int i = 0; i < steps; i++) {
    digitalWrite(MOTOR_STEP, HIGH);
    delayMicroseconds(MOTOR_SPEED);
    digitalWrite(MOTOR_STEP, LOW);
    delayMicroseconds(MOTOR_SPEED);
  }

  digitalWrite(MOTOR_EN, HIGH);  // Disable motor to save power
}

void checkButtons() {
  unsigned long currentTime = millis();

  // Check encoder button
  bool encoderButton = digitalRead(ENCODER_SW);
  if (encoderButton == LOW && lastEncoderButton == HIGH &&
      (currentTime - lastDebounceTimeEncoder) > debounceDelay) {
    queueEvent(EVENT_ENCODER_CLICK, 1);
    lastDebounceTimeEncoder = currentTime;
    buttonPressedAnimation = true;
    buttonPressTime = currentTime;
    shockwaveRadius = 0;
  }
  lastEncoderButton = encoderButton;

  // Check AI button
  bool buttonAI = digitalRead(BUTTON_AI);
  if (buttonAI == LOW && lastButtonAI == HIGH &&
      (currentTime - lastDebounceTimeAI) > debounceDelay) {
    queueEvent(EVENT_BUTTON_AI, 1);
    lastDebounceTimeAI = currentTime;
    buttonPressedAnimation = true;
    buttonPressTime = currentTime;
    shockwaveRadius = 0;
  }
  lastButtonAI = buttonAI;

  // Check Home button
  bool buttonHome = digitalRead(BUTTON_HOME);
  if (buttonHome == LOW && lastButtonHome == HIGH &&
      (currentTime - lastDebounceTimeHome) > debounceDelay) {
    queueEvent(EVENT_BUTTON_HOME, 1);
    lastDebounceTimeHome = currentTime;
    buttonPressedAnimation = true;
    buttonPressTime = currentTime;
    shockwaveRadius = 0;
  }
  lastButtonHome = buttonHome;

  checkEjectButton();
}

void checkEjectButton() {
  unsigned long currentTime = millis();

  // Check Eject button (always active)
  bool buttonEject = digitalRead(BUTTON_EJECT);
  if (buttonEject == LOW && lastButtonEject == HIGH &&
      (currentTime - lastDebounceTimeEject) > debounceDelay) {
    queueEvent(EVENT_BUTTON_EJECT, 1);
    lastDebounceTimeEject = currentTime;
    buttonPressedAnimation = true;
    buttonPressTime = currentTime;
    shockwaveRadius = 0;

    // If phone is locked, eject it
    if (liftState == LIFT_PHONE_LOCKED) {
      liftState = LIFT_EJECTING;
    }
  }
  lastButtonEject = buttonEject;
}

void updateLEDs() {
  unsigned long currentTime = millis();

  // Update at 30fps for smooth animations
  if (currentTime - ledUpdateTime < 33) {
    return;
  }
  ledUpdateTime = currentTime;

  static uint8_t animationCounter = 0;
  animationCounter++;

  int centerLED = NUM_LEDS / 2;  // LED 11 for 23 LEDs

  // Determine base color from environment
  CRGB baseColor;

  if (!TEST_MODE && liftState != LIFT_PHONE_LOCKED) {
    // Phone not locked - pulsing red warning
    baseColor = CRGB::Red;
  } else {
    // Use current environment color
    baseColor = ENV_COLORS[currentEnvironment];

    #if DEBUG_MODE
    static uint8_t debugCounter = 0;
    debugCounter++;
    // Print every 60 frames (once every 2 seconds at 30fps)
    if (debugCounter % 60 == 0) {
      Serial.print("LED: Env=");
      Serial.print(currentEnvironment);
      Serial.print(" Color=");
      Serial.print(baseColor.r);
      Serial.print(",");
      Serial.print(baseColor.g);
      Serial.print(",");
      Serial.println(baseColor.b);
    }
    #endif
  }

  // Draw base animation
  for (int i = 0; i < NUM_LEDS; i++) {
    // Create a subtle wave pattern
    uint8_t wave = sin8(animationCounter * 2 + (i * 256 / NUM_LEDS));
    uint8_t brightness = 100 + (wave >> 2);  // Range: 100-163

    leds[i] = baseColor;
    leds[i].nscale8(brightness);
  }

  // Handle button press shockwave animation
  if (buttonPressedAnimation) {
    unsigned long elapsed = currentTime - buttonPressTime;

    if (elapsed < 500) {  // 500ms animation
      // Calculate shockwave radius (expands over time)
      shockwaveRadius = (elapsed * NUM_LEDS) / 1000;  // Expands to full strip in 500ms

      // Draw shockwave from center
      for (int i = 0; i < NUM_LEDS; i++) {
        int distFromCenter = abs(i - centerLED);

        // Shockwave ring
        if (distFromCenter >= shockwaveRadius - 2 && distFromCenter <= shockwaveRadius + 2) {
          // Fade based on distance from exact radius
          uint8_t intensity = 255 - (abs(distFromCenter - shockwaveRadius) * 85);
          // Fade over time
          intensity = (intensity * (500 - elapsed)) / 500;

          CRGB shockwaveColor = baseColor;
          shockwaveColor.nscale8(255);  // Full brightness
          leds[i] = blend(leds[i], shockwaveColor, intensity);
        }
      }
    } else {
      buttonPressedAnimation = false;
    }
  }

  // Encoder movement - brighten all LEDs
  if (encoderPosition != lastEncoderPos) {
    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].nscale8(200);  // Brighten by 200/255
      leds[i] += baseColor.scale8(55);  // Add 55/255 of base color
    }
    lastEncoderPos = encoderPosition;
  }

  FastLED.show();
}

void queueEvent(uint8_t eventType, int16_t value) {
  uint8_t nextHead = (eventQueueHead + 1) % MAX_EVENTS;
  if (nextHead != eventQueueTail) {
    eventQueue[eventQueueHead].type = eventType;
    eventQueue[eventQueueHead].value = value;
    eventQueueHead = nextHead;
  }
}

bool hasEvents() {
  return eventQueueHead != eventQueueTail;
}

Event dequeueEvent() {
  Event event = eventQueue[eventQueueTail];
  eventQueueTail = (eventQueueTail + 1) % MAX_EVENTS;
  return event;
}

bool processCommand() {
  // Peek at start byte without consuming it
  if (Serial.peek() != START_BYTE) {
    // Flush bad data (up to 10 bytes to prevent blocking)
    for (int i = 0; i < 10 && Serial.available() > 0 && Serial.peek() != START_BYTE; i++) {
      Serial.read();
    }
    return true;  // Continue processing
  }

  // Check if we have minimum packet: START + CMD + LEN
  if (Serial.available() < 3) {
    return false;  // Incomplete packet, wait for more data
  }

  // Now we can safely read start byte
  Serial.read();  // Consume START_BYTE

  uint8_t cmd = Serial.read();
  uint8_t dataLen = Serial.read();

  // Check if we have all the data available NOW (non-blocking)
  if (Serial.available() < (dataLen + 1)) {
    // Not enough data yet - we already consumed 3 bytes, this packet is lost
    // Flush what we can to resync
    while (Serial.available() > 0 && Serial.peek() != START_BYTE) {
      Serial.read();
    }
    return false;  // Packet incomplete
  }

  // Read data bytes (we know they're all there)
  uint8_t data[16];
  for (int i = 0; i < dataLen && i < 16; i++) {
    data[i] = Serial.read();
  }

  // Read checksum
  uint8_t receivedChecksum = Serial.read();

  // Verify checksum
  uint8_t calculatedChecksum = cmd ^ dataLen;
  for (int i = 0; i < dataLen; i++) {
    calculatedChecksum ^= data[i];
  }

  if (calculatedChecksum != receivedChecksum) {
    return true;  // Checksum mismatch, continue processing
  }

  // Process command
  switch (cmd) {
    case CMD_PING:
      sendResponse(RESP_PONG, NULL, 0);
      break;

    case CMD_GET_ENCODER:
      {
        uint8_t encData[2];
        encData[0] = (encoderPosition >> 8) & 0xFF;
        encData[1] = encoderPosition & 0xFF;
        sendResponse(RESP_ENCODER, encData, 2);
      }
      break;

    case CMD_GET_BUTTONS:
      {
        uint8_t buttonStates = 0;
        if (digitalRead(ENCODER_SW) == LOW) buttonStates |= 0x01;
        if (digitalRead(BUTTON_AI) == LOW) buttonStates |= 0x02;
        if (digitalRead(BUTTON_HOME) == LOW) buttonStates |= 0x04;
        if (digitalRead(BUTTON_EJECT) == LOW) buttonStates |= 0x08;
        sendResponse(RESP_BUTTONS, &buttonStates, 1);
      }
      break;

    case CMD_SET_LED:
      // Future: Set LED brightness/color
      sendResponse(RESP_LED_ACK, NULL, 0);
      break;

    case CMD_GET_EVENTS:
      {
        // Send up to 5 events at once
        uint8_t eventData[15];  // 5 events * 3 bytes each
        uint8_t eventCount = 0;

        while (hasEvents() && eventCount < 5) {
          Event evt = dequeueEvent();
          eventData[eventCount * 3] = evt.type;
          eventData[eventCount * 3 + 1] = (evt.value >> 8) & 0xFF;
          eventData[eventCount * 3 + 2] = evt.value & 0xFF;
          eventCount++;
        }

        sendResponse(RESP_EVENTS, eventData, eventCount * 3);
      }
      break;

    case CMD_GET_PHONE_STATUS:
      {
        uint8_t phoneData[2];
        phoneData[0] = phonePresent ? 1 : 0;
        phoneData[1] = (uint8_t)liftState;
        sendResponse(RESP_PHONE_STATUS, phoneData, 2);
      }
      break;

    case CMD_SET_ENVIRONMENT:
      {
        if (dataLen >= 1) {
          uint8_t envId = data[0];
          if (envId <= ENV_GARDEN) {
            currentEnvironment = (EnvironmentMode)envId;

            #if DEBUG_MODE
            Serial.print("🎨 RECEIVED environment: ");
            Serial.println(envId);
            #endif

            sendResponse(RESP_ENV_ACK, NULL, 0);
          }
        }
      }
      break;

    case CMD_EJECT_PHONE:
      {
        if (liftState == LIFT_PHONE_LOCKED) {
          liftState = LIFT_EJECTING;
        }
        sendResponse(RESP_EJECT_ACK, NULL, 0);
      }
      break;

    case CMD_SET_MOTOR_SPEED:
      {
        if (dataLen >= 2) {
          MOTOR_SPEED = (data[0] << 8) | data[1];
          sendResponse(RESP_MOTOR_SPEED_ACK, NULL, 0);
        }
      }
      break;
  }

  return true;  // Successfully processed command
}

void sendResponse(uint8_t responseCode, uint8_t* data, uint8_t dataLen) {
  // Send start byte
  Serial.write(START_BYTE);

  // Send response code and length
  Serial.write(responseCode);
  Serial.write(dataLen);

  // Send data
  for (int i = 0; i < dataLen; i++) {
    Serial.write(data[i]);
  }

  // Calculate and send checksum
  uint8_t checksum = responseCode ^ dataLen;
  for (int i = 0; i < dataLen; i++) {
    checksum ^= data[i];
  }
  Serial.write(checksum);
}
