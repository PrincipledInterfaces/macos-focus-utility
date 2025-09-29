#include <FastLED.h>

#define LED_PIN     4
#define NUM_LEDS    11
#define BRIGHTNESS  64
#define UPDATES_PER_SECOND 100

CRGB leds[NUM_LEDS];
float progress = 0.0;
float currentMappedProgress = 0.0;
bool shockwaveMode = false;
unsigned long shockwaveStartTime = 0;
const int SHOCKWAVE_DURATION = 500; // 0.5 seconds, much quicker

void setup() {
  Serial.begin(115200);
  FastLED.addLeds<NEOPIXEL, LED_PIN>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  
  // Set initial color (red)
  for (int i = 0; i < NUM_LEDS; i++) {
    leds[i] = CRGB(255, 0, 0);
  }
  FastLED.show();
}

void loop() {
  handleSerialInput();

  if (shockwaveMode) {
    runShockwave();
  } else {
    updateLeds();
  }
  
  FastLED.show();
  delay(1000 / UPDATES_PER_SECOND);
}

void handleSerialInput() {
  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.startsWith("progress:")) {
      String progressString = input.substring(9);
      progress = progressString.toFloat();
      
      // Clamp the progress value between 0 and 100
      if (progress < 0.0) progress = 0.0;
      if (progress > 100.0) progress = 100.0;

      // If we were in shockwave mode, exit it
      shockwaveMode = false;

    } else if (input == "boxchecked") {
      shockwaveMode = true;
      shockwaveStartTime = millis();
    }
  }
}

void updateLeds() {
  // Map progress to a value from 0 to NUM_LEDS
  float targetMappedProgress = map(progress, 0.0, 100.0, 0.0, NUM_LEDS);
  
  // Smoothly transition the mapped progress
  currentMappedProgress = lerp(currentMappedProgress, targetMappedProgress, 0.1);

  // Calculate the base color based on progress
  CRGB baseColor = getColorForProgress(progress);

  // Calculate the number of full LEDs and the fractional part
  int fullLeds = floor(currentMappedProgress);
  float fractionalPart = currentMappedProgress - fullLeds;
  
  for (int i = 0; i < NUM_LEDS; i++) {
    if (i < fullLeds) {
      // LEDs that should be fully on
      leds[i] = fadeToPattern(baseColor, i);
    } else if (i == fullLeds) {
      // The single fading-in LED
      CRGB fadedColor = fadeToPattern(baseColor, fullLeds);
      leds[fullLeds] = fadedColor.nscale8(255 * fractionalPart);
    } else {
      // LEDs that should be off
      leds[i].fadeToBlackBy(10); // Slowly fade to black
    }
  }
}

void runShockwave() {
  unsigned long currentTime = millis();
  unsigned long elapsedTime = currentTime - shockwaveStartTime;

  if (elapsedTime > SHOCKWAVE_DURATION) {
    shockwaveMode = false;
    return;
  }
  
  // Fade all LEDs to black
  fadeToBlackBy(leds, NUM_LEDS, 50);

  // Calculate a "shockwave" position that expands from the center
  float shockwavePos = map(elapsedTime, 0, SHOCKWAVE_DURATION, 0, NUM_LEDS / 2.0);

  // Center LED is index 5
  int center = NUM_LEDS / 2;
  
  // Calculate the position of the first LED in the pair
  int led1Index = center - floor(shockwavePos);
  
  // Calculate the position of the second LED in the pair
  int led2Index = center + floor(shockwavePos);

  // Apply the shockwave effect
  if (led1Index >= 0) {
    leds[led1Index] = CRGB::Green;
  }
  
  if (led2Index < NUM_LEDS && led1Index != led2Index) { // Avoid lighting the same LED twice
    leds[led2Index] = CRGB::Green;
  }
}

CRGB getColorForProgress(float prog) {
  // Create a color palette with more phases
  // Red -> Magenta -> Blue -> Cyan -> Blue (more intense blue)
  if (prog <= 25) {
    // Red to Magenta
    return blend(CRGB(255, 0, 0), CRGB(255, 0, 255), map(prog, 0, 25, 0, 255));
  } else if (prog <= 50) {
    // Magenta to Blue
    return blend(CRGB(255, 0, 255), CRGB(0, 0, 255), map(prog, 25, 50, 0, 255));
  } else if (prog <= 75) {
    // Blue to Cyan
    return blend(CRGB(0, 0, 255), CRGB(0, 255, 255), map(prog, 50, 75, 0, 255));
  } else {
    // Cyan to a more intense Blue
    return blend(CRGB(0, 255, 255), CRGB(0, 0, 255), map(prog, 75, 100, 0, 255));
  }
}

CRGB fadeToPattern(CRGB targetColor, int ledIndex) {
  // A subtle sine wave pattern for a moving effect
  uint8_t patternShift = sin8(millis() / 5 + ledIndex * 25);
  uint8_t colorMod = map(patternShift, 0, 255, -10, 10); // Reduced range for closer shades
  
  int r = targetColor.r + colorMod;
  int g = targetColor.g + colorMod;
  int b = targetColor.b + colorMod;
  
  // Clamp values to stay within 0-255 range
  r = constrain(r, 0, 255);
  g = constrain(g, 0, 255);
  b = constrain(b, 0, 255);
  
  CRGB newColor = CRGB(r, g, b);

  // Smoothly fade from the previous color to the new one
  leds[ledIndex].nscale8(240); // Fade old color by 15/16
  leds[ledIndex] += newColor.nscale8(15);  // Add a small amount of the new color

  return leds[ledIndex];
}

// A simple linear interpolation function
float lerp(float a, float b, float t) {
  return a + t * (b - a);
}