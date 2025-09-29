/*
 * WiFi LED Lamp Controller for Focus Utility
 * 
 * Controls a 30-LED WS2812B strip with two zones:
 * - Back zone: LEDs 0-11 (12 LEDs)
 * - Front zone: LEDs 12-29 (18 LEDs)
 * 
 * Setup Instructions:
 * 1. Install required libraries in Arduino IDE:
 *    - ESP8266WiFi (built-in)
 *    - ESP8266WebServer (built-in)
 *    - ArduinoJson (install from Library Manager)
 *    - FastLED (install from Library Manager)
 *    - WiFiManager (install from Library Manager)
 *    - EEPROM (built-in)
 * 
 * 2. Upload this sketch to your ESP8266
 * 3. On first boot, connect to "FocusLamp-Setup" WiFi network
 * 4. Configure your WiFi credentials through the web portal
 * 5. The lamp will restart and connect to your WiFi
 * 6. Use the Focus Utility plugin to discover and control the lamp
 */

#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ArduinoJson.h>
#include <FastLED.h>
#include <WiFiManager.h>
#include <EEPROM.h>

// LED Configuration
#define LED_PIN 5        // GPIO pin connected to LED strip data line
#define NUM_LEDS 30      // Total number of LEDs
#define BACK_START 0     // Back zone start
#define BACK_COUNT 12    // Back zone LED count
#define FRONT_START 12   // Front zone start  
#define FRONT_COUNT 18   // Front zone LED count

// Network Configuration
#define HTTP_PORT 80
#define DISCOVERY_PORT 8888

// Animation Configuration
#define ANIMATION_SPEED 50  // Base animation speed (ms)

// LED Array
CRGB leds[NUM_LEDS];

// Web Server
ESP8266WebServer server(HTTP_PORT);

// Current lamp state
struct LampState {
  bool active = false;
  String mode = "off";
  uint8_t primaryColor[3] = {0, 0, 0};  // RGB
  uint16_t whiteTemp = 4000;            // Kelvin
  uint8_t movement = 0;                 // 0-100
  bool frontWhite = false;
} lampState;

// Animation variables
unsigned long lastAnimationUpdate = 0;
float animationPhase = 0.0;

// Device info for discovery
String deviceId;

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("Focus Utility WiFi LED Lamp Starting...");
  
  // Generate unique device ID based on MAC address
  deviceId = "FocusLamp_" + WiFi.macAddress();
  deviceId.replace(":", "");
  
  // Initialize LEDs
  FastLED.addLeds<WS2812B, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(255);
  FastLED.clear();
  FastLED.show();
  
  // Show startup animation
  startupAnimation();
  
  // Configure WiFiManager
  WiFiManager wifiManager;
  
  // Uncomment to reset WiFi settings for testing
  // wifiManager.resetSettings();
  
  wifiManager.setAPCallback(configModeCallback);
  
  // Try to connect to WiFi, or start config portal
  if (!wifiManager.autoConnect("FocusLamp-Setup")) {
    Serial.println("Failed to connect to WiFi");
    delay(3000);
    ESP.restart();
  }
  
  Serial.println("WiFi connected successfully!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  Serial.print("Device ID: ");
  Serial.println(deviceId);
  
  // Setup web server routes
  setupWebServer();
  
  // Start the server
  server.begin();
  Serial.println("HTTP server started");
  
  // Show connection success animation
  connectionSuccessAnimation();
}

void loop() {
  // Handle web requests
  server.handleClient();
  
  // Update LED animations if active
  if (lampState.active) {
    updateAnimation();
  }
  
  // Keep WiFi alive
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, attempting reconnection...");
    WiFi.reconnect();
  }
  
  delay(10);
}

void configModeCallback(WiFiManager *myWiFiManager) {
  Serial.println("Entered config mode");
  Serial.println(WiFi.softAPIP());
  Serial.println(myWiFiManager->getConfigPortalSSID());
  
  // Show config mode animation
  configModeAnimation();
}

void setupWebServer() {
  // Discovery endpoint
  server.on("/discover", HTTP_GET, []() {
    DynamicJsonDocument doc(256);
    doc["device"] = "focus_lamp";
    doc["id"] = deviceId;
    doc["name"] = "Focus LED Lamp";
    doc["ip"] = WiFi.localIP().toString();
    doc["version"] = "1.0.0";
    
    String response;
    serializeJson(doc, response);
    
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(200, "application/json", response);
  });
  
  // Status endpoint
  server.on("/status", HTTP_GET, []() {
    DynamicJsonDocument doc(512);
    doc["active"] = lampState.active;
    doc["mode"] = lampState.mode;
    
    JsonArray color = doc.createNestedArray("primaryColor");
    color.add(lampState.primaryColor[0]);
    color.add(lampState.primaryColor[1]);
    color.add(lampState.primaryColor[2]);
    
    doc["whiteTemp"] = lampState.whiteTemp;
    doc["movement"] = lampState.movement;
    doc["frontWhite"] = lampState.frontWhite;
    
    String response;
    serializeJson(doc, response);
    
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(200, "application/json", response);
  });
  
  // Control endpoint
  server.on("/control", HTTP_POST, []() {
    if (!server.hasArg("plain")) {
      server.send(400, "text/plain", "No JSON body");
      return;
    }
    
    DynamicJsonDocument doc(512);
    deserializeJson(doc, server.arg("plain"));
    
    // Parse command
    String command = doc["command"];
    
    if (command == "set_mode") {
      Serial.println("DEBUG: Received set_mode command");
      Serial.printf("DEBUG: Full JSON received: %s\\n", server.arg("plain").c_str());
      
      lampState.active = true;
      lampState.mode = doc["mode"].as<String>();
      
      JsonArray color = doc["primaryColor"];
      lampState.primaryColor[0] = color[0];
      lampState.primaryColor[1] = color[1];
      lampState.primaryColor[2] = color[2];
      
      lampState.whiteTemp = doc["whiteTemp"];
      lampState.movement = doc["movement"];
      lampState.frontWhite = doc["frontWhite"];
      
      Serial.printf("DEBUG: Setting mode: %s\\n", lampState.mode.c_str());
      Serial.printf("DEBUG: Primary color: RGB(%d,%d,%d)\\n", 
                    lampState.primaryColor[0], 
                    lampState.primaryColor[1], 
                    lampState.primaryColor[2]);
      Serial.printf("DEBUG: Movement: %d\\n", lampState.movement);
      Serial.printf("DEBUG: Front white: %s\\n", lampState.frontWhite ? "true" : "false");
      Serial.printf("DEBUG: White temp: %d\\n", lampState.whiteTemp);
      
      // Force immediate color refresh to clear any cached/previous colors
      FastLED.clear();
      FastLED.show();
      delay(50);
      
      // Show mode transition
      modeTransitionAnimation();
      
    } else if (command == "turn_off") {
      Serial.println("Turning off lamp");
      lampState.active = false;
      lampState.mode = "off";
      
      // Show turn off transition
      turnOffAnimation();
      
    } else if (command == "transition") {
      // Show generic transition animation
      transitionAnimation();
    }
    
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.send(200, "application/json", "{\"status\":\"ok\"}");
  });
  
  // CORS preflight
  server.on("/control", HTTP_OPTIONS, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.sendHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
    server.send(204);
  });
}

void updateAnimation() {
  unsigned long now = millis();
  
  // Much faster update rate based on movement
  int updateInterval = max(10, ANIMATION_SPEED - (lampState.movement * 2)); // Was just movement, now movement * 2
  if (now - lastAnimationUpdate < updateInterval) {
    return;
  }
  
  lastAnimationUpdate = now;
  // Smooth, calm animation speed - no more jarring changes
  animationPhase += 0.02 + (lampState.movement * 0.003);  // Much slower for fluid, calming effect
  
  if (animationPhase > TWO_PI) {
    animationPhase -= TWO_PI;
  }
  
  // Debug output every 2 seconds
  static unsigned long lastDebug = 0;
  if (now - lastDebug > 2000) {
    Serial.printf("DEBUG: Animation running, phase=%.2f, active=%s, movement=%d, interval=%d\n", 
                  animationPhase, lampState.active ? "true" : "false", lampState.movement, updateInterval);
    lastDebug = now;
  }
  
  // Don't clear - we want smooth transitions
  
  // Back zone (always colored with animation)
  for (int i = BACK_START; i < BACK_START + BACK_COUNT; i++) {
    CRGB color = getAnimatedColor(i);
    leds[i] = color;
  }
  
  // Front zone
  for (int i = FRONT_START; i < FRONT_START + FRONT_COUNT; i++) {
    if (lampState.frontWhite) {
      // Static white light
      leds[i] = kelvinToRGB(lampState.whiteTemp);
    } else {
      // Animated color
      CRGB color = getAnimatedColor(i);
      leds[i] = color;
    }
  }
  
  FastLED.show();
}

CRGB getAnimatedColor(int ledIndex) {
  // Base color from primary - use exact RGB to preserve color accuracy
  CRGB baseRGB = CRGB(lampState.primaryColor[0], 
                      lampState.primaryColor[1], 
                      lampState.primaryColor[2]);
  
  // Debug output for first LED only to avoid spam
  if (ledIndex == 0 && millis() % 3000 < 100) {
    Serial.printf("DEBUG: Base RGB=(%d,%d,%d), movement=%d\n", 
                  baseRGB.r, baseRGB.g, baseRGB.b, lampState.movement);
  }
  
  // Use pure RGB-based animation to avoid HSV color shifts
  float movementFactor = lampState.movement / 100.0;
  
  // Position-based phase for wave effects
  float positionPhase = (float)ledIndex / NUM_LEDS * TWO_PI;
  
  // Create gentle breathing/wave effect using only brightness variation
  // This preserves the exact color while creating movement
  float brightnessWave1 = sin(animationPhase * 0.4 + positionPhase) * movementFactor;
  float brightnessWave2 = sin(animationPhase * 0.7 + positionPhase * 0.6) * movementFactor * 0.5;
  float totalBrightnessVariation = (brightnessWave1 + brightnessWave2) * 0.3; // Keep very subtle
  
  // Apply brightness variation to RGB components equally to preserve color
  float brightnessFactor = 1.0 + totalBrightnessVariation;
  brightnessFactor = constrain(brightnessFactor, 0.7, 1.0); // Prevent too dim or too bright
  
  CRGB result;
  result.r = constrain((int)(baseRGB.r * brightnessFactor), 0, 255);
  result.g = constrain((int)(baseRGB.g * brightnessFactor), 0, 255);
  result.b = constrain((int)(baseRGB.b * brightnessFactor), 0, 255);
  
  return result;
}

CRGB kelvinToRGB(uint16_t kelvin) {
  // Simplified Kelvin to RGB conversion
  float temp = kelvin / 100.0;
  uint8_t r, g, b;
  
  if (temp <= 66) {
    r = 255;
    g = temp;
    g = 99.4708025861 * log(g) - 161.1195681661;
    g = constrain(g, 0, 255);
    
    if (temp >= 19) {
      b = temp - 10;
      b = 138.5177312231 * log(b) - 305.0447927307;
      b = constrain(b, 0, 255);
    } else {
      b = 0;
    }
  } else {
    r = temp - 60;
    r = 329.698727446 * pow(r, -0.1332047592);
    r = constrain(r, 0, 255);
    
    g = temp - 60;
    g = 288.1221695283 * pow(g, -0.0755148492);
    g = constrain(g, 0, 255);
    
    b = 255;
  }
  
  return CRGB(r, g, b);
}

// Animation Functions
void startupAnimation() {
  Serial.println("Playing startup animation");
  
  // Gentle breathing rainbow that starts from center and expands
  for (int cycle = 0; cycle < 3; cycle++) {
    for (int phase = 0; phase < 360; phase += 2) {
      FastLED.clear();
      
      float brightness = (sin(radians(phase)) + 1.0) * 0.3 + 0.1; // 0.1 to 0.7 range
      int hue = (phase / 2 + cycle * 85) % 255; // Slow color shift
      
      // Expand from center outward
      int center = NUM_LEDS / 2;
      int radius = (int)(brightness * 15);
      
      for (int i = 0; i < NUM_LEDS; i++) {
        int distance = abs(i - center);
        if (distance <= radius) {
          float ledBrightness = (1.0 - (float)distance / radius) * brightness * 255;
          leds[i] = CHSV(hue, 200, (int)ledBrightness);
        }
      }
      
      FastLED.show();
      delay(25);
    }
  }
  
  // Gentle fade to off
  for (int fade = 255; fade >= 0; fade -= 3) {
    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].fadeToBlackBy(3);
    }
    FastLED.show();
    delay(15);
  }
  
  FastLED.clear();
  FastLED.show();
}

void configModeAnimation() {
  // Gentle blue breathing to indicate config mode
  for (int pulse = 0; pulse < 5; pulse++) {
    for (int phase = 0; phase < 360; phase += 3) {
      float brightness = (sin(radians(phase)) + 1.0) * 0.4 + 0.1; // 0.1 to 0.9 range
      
      for (int i = 0; i < NUM_LEDS; i++) {
        // Slight position offset for a wave effect
        float offset = sin(i * 0.3) * 0.2;
        float ledBrightness = (brightness + offset) * 255;
        ledBrightness = constrain(ledBrightness, 20, 255);
        
        leds[i] = CHSV(160, 255, (int)ledBrightness);
      }
      
      FastLED.show();
      delay(35);
    }
  }
  
  // Gentle fade out
  for (int fade = 0; fade < 100; fade++) {
    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].fadeToBlackBy(3);
    }
    FastLED.show();
    delay(20);
  }
}

void connectionSuccessAnimation() {
  Serial.println("Playing connection success animation");
  
  // Smooth green wave that builds up
  for (int wave = 0; wave < 2; wave++) {
    // Wave moving left to right
    for (int pos = -8; pos < NUM_LEDS + 8; pos++) {
      for (int i = 0; i < NUM_LEDS; i++) {
        int distance = abs(i - pos);
        if (distance < 8) {
          float brightness = (1.0 - (float)distance / 8.0) * 255;
          // Blend with existing color for smooth trails
          CRGB existing = leds[i];
          CRGB newColor = CHSV(96, 255, (int)brightness);
          leds[i] = blend(existing, newColor, 180);
        } else {
          // Fade existing pixels
          leds[i].fadeToBlackBy(15);
        }
      }
      FastLED.show();
      delay(35);
    }
    
    // Brief pause between waves
    for (int fade = 0; fade < 30; fade++) {
      for (int i = 0; i < NUM_LEDS; i++) {
        leds[i].fadeToBlackBy(8);
      }
      FastLED.show();
      delay(20);
    }
  }
  
  // Final celebratory flash
  fill_solid(leds, NUM_LEDS, CHSV(96, 255, 150));
  FastLED.show();
  delay(200);
  
  // Fade to off
  for (int fade = 0; fade < 150; fade++) {
    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].fadeToBlackBy(2);
    }
    FastLED.show();
    delay(10);
  }
}

void modeTransitionAnimation() {
  Serial.println("Playing mode transition animation");
  
  CRGB newColor = CRGB(lampState.primaryColor[0], 
                       lampState.primaryColor[1], 
                       lampState.primaryColor[2]);
  
  Serial.printf("DEBUG: Transition color RGB(%d,%d,%d)\n", newColor.r, newColor.g, newColor.b);
  Serial.printf("DEBUG: lampState.active = %s\n", lampState.active ? "true" : "false");
  
  // Store current LED states for smooth transition
  CRGB oldLeds[NUM_LEDS];
  for (int i = 0; i < NUM_LEDS; i++) {
    oldLeds[i] = leds[i];
  }
  
  // Beautiful wave transition from center outward
  int center = NUM_LEDS / 2;
  for (int radius = 0; radius <= NUM_LEDS / 2 + 5; radius++) {
    for (int i = 0; i < NUM_LEDS; i++) {
      int distance = abs(i - center);
      
      if (distance <= radius) {
        // LED is inside the transition wave - blend to new color
        float blendAmount = 1.0 - (float)distance / (radius + 1);
        blendAmount = blendAmount * blendAmount; // Ease-in effect
        blendAmount = constrain(blendAmount * 255, 0, 255);
        
        leds[i] = blend(oldLeds[i], newColor, (uint8_t)blendAmount);
      } else {
        // LED hasn't been reached yet - keep old color but fade slightly
        leds[i] = oldLeds[i];
        leds[i].fadeToBlackBy(5);
      }
    }
    
    FastLED.show();
    delay(60);
  }
  
  // Ensure all LEDs are set to the new color
  for (int i = 0; i < NUM_LEDS; i++) {
    leds[i] = newColor;
  }
  
  // Gentle brightness pulse to "activate" the new mode
  for (int pulse = 0; pulse < 2; pulse++) {
    for (int phase = 0; phase < 180; phase += 3) {
      float brightness = sin(radians(phase)) * 0.3 + 0.7; // 0.7 to 1.0 range
      
      for (int i = 0; i < NUM_LEDS; i++) {
        CRGB pulsedColor = newColor;
        pulsedColor.fadeToBlackBy(255 - (int)(brightness * 255));
        leds[i] = pulsedColor;
      }
      
      FastLED.show();
      delay(25);
    }
  }
  
  // Set to final color and force display
  for (int i = 0; i < NUM_LEDS; i++) {
    leds[i] = newColor;
  }
  FastLED.show();
  delay(100);  // Small delay to ensure the color is displayed
  
  // Double-check: Set again to ensure color accuracy
  for (int i = 0; i < NUM_LEDS; i++) {
    leds[i] = CRGB(lampState.primaryColor[0], lampState.primaryColor[1], lampState.primaryColor[2]);
  }
  FastLED.show();
  
  Serial.printf("DEBUG: Transition complete, lampState.active = %s\n", lampState.active ? "true" : "false");
  Serial.printf("DEBUG: Final color set to RGB(%d,%d,%d)\n", 
                lampState.primaryColor[0], lampState.primaryColor[1], lampState.primaryColor[2]);
}

void turnOffAnimation() {
  Serial.println("Playing turn off animation");
  
  // Gentle wave fade from outside to center
  for (int wave = 0; wave < NUM_LEDS / 2 + 8; wave++) {
    for (int i = 0; i < NUM_LEDS; i++) {
      int distanceFromEdge = min(i, NUM_LEDS - 1 - i);
      
      if (distanceFromEdge <= wave) {
        // This LED should start fading
        int fadeAmount = (wave - distanceFromEdge + 1) * 12; // Increased fade amount
        fadeAmount = constrain(fadeAmount, 0, 255);
        leds[i].fadeToBlackBy(fadeAmount);
      }
    }
    
    FastLED.show();
    delay(60); // Slightly faster
  }
  
  // Additional safety fade to ensure everything is off
  for (int extraFade = 0; extraFade < 20; extraFade++) {
    for (int i = 0; i < NUM_LEDS; i++) {
      if (leds[i].r > 0 || leds[i].g > 0 || leds[i].b > 0) {
        leds[i].fadeToBlackBy(20);
      }
    }
    FastLED.show();
    delay(30);
  }
  
  // Ensure all LEDs are completely off
  FastLED.clear();
  FastLED.show();
  
  Serial.println("DEBUG: Turn off animation complete - all LEDs should be off");
}

void transitionAnimation() {
  Serial.println("Playing transition animation");
  
  // Smooth rainbow spiral for test/transition
  for (int phase = 0; phase < 720; phase += 4) {
    for (int i = 0; i < NUM_LEDS; i++) {
      // Create a flowing rainbow with position and time offset
      int hue = (phase + i * 8) % 255;
      float brightness = (sin(radians(phase * 2 + i * 20)) + 1.0) * 0.4 + 0.3; // 0.3 to 1.1 range
      brightness = constrain(brightness, 0.3, 0.8);
      
      leds[i] = CHSV(hue, 200, (int)(brightness * 255));
    }
    
    FastLED.show();
    delay(25);
  }
  
  // Gentle fade to off
  for (int fade = 0; fade < 100; fade++) {
    for (int i = 0; i < NUM_LEDS; i++) {
      leds[i].fadeToBlackBy(4);
    }
    FastLED.show();
    delay(20);
  }
}