/*
 * TOME Hardware Controller - ESP8266
 *
 * Hardware Setup:
 * - Rotary Encoder: CLK -> D5, DT -> D6, SW -> D7
 * - Button 1 (AI Chat): D1
 * - Button 2 (Home): D2
 * - Button 3 (Phone Eject): D3
 * - Future ARGB LED Strip: D4
 *
 * Communication: Serial over USB at 115200 baud
 * Protocol: Binary packet-based with checksums
 */

#include <Arduino.h>

// Forward declarations
void ICACHE_RAM_ATTR handleEncoder();

// Pin Definitions
#define ENCODER_CLK 5
#define ENCODER_DT  4
#define ENCODER_SW  2
#define BUTTON_AI   14
#define BUTTON_HOME 12
#define BUTTON_EJECT 13
#define LED_PIN     15  // For future ARGB strip

// Protocol Constants
#define START_BYTE 0xFF

// Commands (from host)
enum Command {
  CMD_PING = 0x01,
  CMD_GET_ENCODER = 0x02,
  CMD_GET_BUTTONS = 0x03,
  CMD_SET_LED = 0x04,
  CMD_GET_EVENTS = 0x05
};

// Responses (to host)
enum Response {
  RESP_PONG = 0x81,
  RESP_ENCODER = 0x82,
  RESP_BUTTONS = 0x83,
  RESP_LED_ACK = 0x84,
  RESP_EVENTS = 0x85
};

// Event Types
enum EventType {
  EVENT_ENCODER_CW = 0x01,      // Clockwise rotation
  EVENT_ENCODER_CCW = 0x02,     // Counter-clockwise rotation
  EVENT_ENCODER_CLICK = 0x03,   // Encoder button pressed
  EVENT_BUTTON_AI = 0x04,       // AI chat button pressed
  EVENT_BUTTON_HOME = 0x05,     // Home button pressed
  EVENT_BUTTON_EJECT = 0x06     // Phone eject button pressed
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

// Event queue
#define MAX_EVENTS 32
struct Event {
  uint8_t type;
  int16_t value;
};
Event eventQueue[MAX_EVENTS];
uint8_t eventQueueHead = 0;
uint8_t eventQueueTail = 0;

// Debouncing
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;

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

  // Configure LED pin for future use
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Attach interrupt for encoder
  attachInterrupt(digitalPinToInterrupt(ENCODER_CLK), handleEncoder, CHANGE);

  // Initialize encoder state
  lastEncoderCLK = digitalRead(ENCODER_CLK);

  // Startup blink
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_BUILTIN, LOW);
    delay(100);
    digitalWrite(LED_BUILTIN, HIGH);
    delay(100);
  }
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

  // Check for incoming commands
  if (Serial.available() >= 4) {  // Minimum packet size
    processCommand();
  }

  // Check buttons
  checkButtons();

  // Small delay to prevent overwhelming the serial port
  delay(10);
}

void ICACHE_RAM_ATTR handleEncoder() {
  // Debounce - ignore changes faster than 5ms
  unsigned long currentTime = millis();
  if (currentTime - lastEncoderTime < 5) {
    return;
  }

  // Read the current state
  int clkState = digitalRead(ENCODER_CLK);
  int dtState = digitalRead(ENCODER_DT);

  // Only process on CLK falling edge
  if (clkState != lastEncoderCLK && clkState == LOW) {
    // Determine direction
    if (dtState != clkState) {
      // Clockwise
      encoderPosition++;
      encoderDirection = 1;
      encoderChanged = true;
      lastEncoderTime = currentTime;
    } else {
      // Counter-clockwise
      encoderPosition--;
      encoderDirection = -1;
      encoderChanged = true;
      lastEncoderTime = currentTime;
    }
  }

  lastEncoderCLK = clkState;
}

void checkButtons() {
  unsigned long currentTime = millis();

  // Check encoder button
  bool encoderButton = digitalRead(ENCODER_SW);
  if (encoderButton == LOW && lastEncoderButton == HIGH &&
      (currentTime - lastDebounceTime) > debounceDelay) {
    queueEvent(EVENT_ENCODER_CLICK, 1);
    lastDebounceTime = currentTime;
  }
  lastEncoderButton = encoderButton;

  // Check AI button
  bool buttonAI = digitalRead(BUTTON_AI);
  if (buttonAI == LOW && lastButtonAI == HIGH &&
      (currentTime - lastDebounceTime) > debounceDelay) {
    queueEvent(EVENT_BUTTON_AI, 1);
    lastDebounceTime = currentTime;
    // Visual feedback - blink LED
    digitalWrite(LED_BUILTIN, LOW);
    delay(100);
    digitalWrite(LED_BUILTIN, HIGH);
  }
  lastButtonAI = buttonAI;

  // Check Home button
  bool buttonHome = digitalRead(BUTTON_HOME);
  if (buttonHome == LOW && lastButtonHome == HIGH &&
      (currentTime - lastDebounceTime) > debounceDelay) {
    queueEvent(EVENT_BUTTON_HOME, 1);
    lastDebounceTime = currentTime;
  }
  lastButtonHome = buttonHome;

  // Check Eject button
  bool buttonEject = digitalRead(BUTTON_EJECT);
  if (buttonEject == LOW && lastButtonEject == HIGH &&
      (currentTime - lastDebounceTime) > debounceDelay) {
    queueEvent(EVENT_BUTTON_EJECT, 1);
    lastDebounceTime = currentTime;
  }
  lastButtonEject = buttonEject;
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

void processCommand() {
  // Read start byte
  uint8_t startByte = Serial.read();
  if (startByte != START_BYTE) {
    return;  // Not a valid packet
  }

  // Read command and length
  if (Serial.available() < 2) return;
  uint8_t cmd = Serial.read();
  uint8_t dataLen = Serial.read();

  // Read data bytes
  uint8_t data[16];
  for (int i = 0; i < dataLen && i < 16; i++) {
    while (!Serial.available());
    data[i] = Serial.read();
  }

  // Read checksum
  while (!Serial.available());
  uint8_t receivedChecksum = Serial.read();

  // Verify checksum
  uint8_t calculatedChecksum = cmd ^ dataLen;
  for (int i = 0; i < dataLen; i++) {
    calculatedChecksum ^= data[i];
  }

  if (calculatedChecksum != receivedChecksum) {
    return;  // Checksum mismatch
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
  }
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
