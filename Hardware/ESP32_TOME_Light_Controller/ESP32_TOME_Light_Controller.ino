/*
 * TOME Light Controller - ESP32 WROOM
 *
 * Controls an ARGB LED strip with scrolling gradient animations.
 * Receives commands via text-based serial protocol at 115200 baud.
 *
 * Hardware Setup:
 * - ARGB LED Strip (WS2812B): GPIO 27
 *
 * Serial Protocol:
 *   Send:    l:(#rrggbb, #rrggbb, ...)
 *   Receive: OK
 *
 *   Short hex also supported: #rgb (expands to #rrggbb)
 *
 * Handshake (to distinguish from TOME hardware controller):
 *   Send:    TOME_IDENTIFY
 *   Receive: TOME_LIGHT_CONTROLLER_V1
 *
 * The strip displays a scrolling animated gradient across all provided colors.
 * When a new command arrives, it smoothly crossfades from the current animation
 * into the new gradient instead of cutting instantly.
 *
 * Adjust NUM_LEDS to match your strip length.
 */

#include <Arduino.h>
#include <FastLED.h>

// ── Hardware ────────────────────────────────────────────────────────────────
// On ESP32-WROOM DevKit the silkscreened label IS the GPIO number.
// "Pin 27" on the board = GPIO 27 = use 27 here. No remapping needed.
#define LED_PIN       27
#define NUM_LEDS      59    // ← Set this to your actual strip LED count

// ── Timing ──────────────────────────────────────────────────────────────────
#define FRAME_MS          30    // ~33fps
#define SCROLL_SPEED       1    // Scroll offset increment per frame
#define TRANSITION_MS    600    // Crossfade duration when palette changes (ms)

// ── Palette ──────────────────────────────────────────────────────────────────
#define MAX_PALETTE_COLORS 16

CRGB activePalette[MAX_PALETTE_COLORS];
int  activePaletteCount = 0;

CRGB oldPalette[MAX_PALETTE_COLORS];
int  oldPaletteCount = 0;

// ── State ────────────────────────────────────────────────────────────────────
CRGB leds[NUM_LEDS];

unsigned long scrollOffset   = 0;
unsigned long lastFrameTime  = 0;

bool          transitioning    = false;
unsigned long transitionStart  = 0;

// ── Serial input ─────────────────────────────────────────────────────────────
#define INPUT_BUFFER_SIZE 512
char inputBuffer[INPUT_BUFFER_SIZE];
int  bufferPos = 0;

// ── Gradient rendering ────────────────────────────────────────────────────────

// Sample a cyclic gradient at position pos with a scroll offset applied,
// using the provided palette.
CRGB sampleGradient(int pos, unsigned long offset,
                    const CRGB* pal, int palCount) {
  if (palCount == 0) return CRGB::Black;
  if (palCount == 1) return pal[0];

  // Reverse scroll direction: subtract offset instead of adding.
  // Use unsigned arithmetic: (pos + NUM_LEDS - (offset % NUM_LEDS)) is always in [1, 117].
  // fmod maps that to [0, NUM_LEDS), so t is always in [0, 1) with no negatives.
  unsigned long wrapped = (unsigned long)pos + NUM_LEDS - (offset % NUM_LEDS);
  float t = fmod((float)wrapped, (float)NUM_LEDS) / (float)NUM_LEDS;

  // Map to palette segment
  float scaled = t * (float)palCount;
  int   idx0   = (int)scaled % palCount;
  int   idx1   = (idx0 + 1) % palCount;
  uint8_t frac = (uint8_t)((scaled - (float)(int)scaled) * 255.0f);

  return blend(pal[idx0], pal[idx1], frac);
}

// Render a full frame into buf using the given palette and scroll offset.
void renderGradient(CRGB* buf, unsigned long offset,
                    const CRGB* pal, int palCount) {
  for (int i = 0; i < NUM_LEDS; i++) {
    buf[i] = sampleGradient(i, offset, pal, palCount);
  }
}

// ── Update loop ───────────────────────────────────────────────────────────────

void updateLEDs() {
  unsigned long now = millis();
  if (now - lastFrameTime < FRAME_MS) return;
  lastFrameTime = now;

  scrollOffset += SCROLL_SPEED;

  if (activePaletteCount == 0) {
    fill_solid(leds, NUM_LEDS, CRGB::Black);
    FastLED.show();
    return;
  }

  if (transitioning) {
    unsigned long elapsed = now - transitionStart;

    if (elapsed >= TRANSITION_MS) {
      // Transition complete — snap to new gradient
      transitioning = false;
      renderGradient(leds, scrollOffset, activePalette, activePaletteCount);
    } else {
      // Both old and new gradients scroll in sync; blend between them
      uint8_t amount = (uint8_t)((elapsed * 255UL) / TRANSITION_MS);

      CRGB oldFrame[NUM_LEDS];
      CRGB newFrame[NUM_LEDS];
      renderGradient(oldFrame, scrollOffset, oldPalette, oldPaletteCount);
      renderGradient(newFrame, scrollOffset, activePalette, activePaletteCount);

      for (int i = 0; i < NUM_LEDS; i++) {
        leds[i] = blend(oldFrame[i], newFrame[i], amount);
      }
    }
  } else {
    renderGradient(leds, scrollOffset, activePalette, activePaletteCount);
  }

  FastLED.show();
}

// ── Hex color parsing ─────────────────────────────────────────────────────────

// Returns the number of valid hex digits consumed from src into clean (max 6).
static int collectHexDigits(const char* src, char* clean) {
  int count = 0;
  while (*src && count < 6) {
    if (isxdigit((unsigned char)*src)) {
      clean[count++] = *src;
    } else {
      break;
    }
    src++;
  }
  clean[count] = '\0';
  return count;
}

bool parseHexColor(const char* token, CRGB& out) {
  const char* p = token;
  while (*p == ' ') p++;     // skip leading whitespace
  if (*p == '#') p++;        // skip #

  char clean[7];
  int count = collectHexDigits(p, clean);

  if (count == 3) {
    // #rgb → #rrggbb
    char expanded[7];
    expanded[0] = clean[0]; expanded[1] = clean[0];
    expanded[2] = clean[1]; expanded[3] = clean[1];
    expanded[4] = clean[2]; expanded[5] = clean[2];
    expanded[6] = '\0';
    uint32_t v = strtoul(expanded, NULL, 16);
    out = CRGB((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
    return true;
  }

  if (count >= 4) {
    // Pad to 6 digits with trailing zeros if needed
    while (count < 6) clean[count++] = '0';
    clean[6] = '\0';
    uint32_t v = strtoul(clean, NULL, 16);
    out = CRGB((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
    return true;
  }

  return false;  // too short to be a valid color
}

// ── Command parsing ───────────────────────────────────────────────────────────

// Parses:  l:(#rrggbb, #rrggbb, ...)
void parseLightCommand(const char* line) {
  const char* p = strchr(line, '(');
  if (!p) { Serial.println("ERR:no_open_paren"); return; }
  p++;

  CRGB newPalette[MAX_PALETTE_COLORS];
  int  count = 0;

  while (*p && *p != ')' && count < MAX_PALETTE_COLORS) {
    // Skip whitespace and commas
    while (*p == ' ' || *p == ',') p++;
    if (*p == ')' || *p == '\0') break;

    CRGB c;
    if (parseHexColor(p, c)) {
      newPalette[count++] = c;
    }

    // Advance past this token (to next comma or closing paren)
    while (*p && *p != ',' && *p != ')') p++;
  }

  if (count == 0) { Serial.println("ERR:no_colors"); return; }

  // Begin crossfade transition
  memcpy(oldPalette, activePalette, sizeof(CRGB) * activePaletteCount);
  oldPaletteCount = (activePaletteCount > 0) ? activePaletteCount : 1;
  if (activePaletteCount == 0) oldPalette[0] = CRGB::Black;

  memcpy(activePalette, newPalette, sizeof(CRGB) * count);
  activePaletteCount = count;

  transitioning   = true;
  transitionStart = millis();

  Serial.println("OK");
}

void processLine(const char* line) {
  if (strcmp(line, "TOME_IDENTIFY") == 0) {
    Serial.println("TOME_LIGHT_CONTROLLER_V1");
  } else if (line[0] == 'l' && line[1] == ':') {
    parseLightCommand(line);
  }
  // Unknown commands are silently ignored
}

// ── Serial input ──────────────────────────────────────────────────────────────

void readSerial() {
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (bufferPos > 0) {
        inputBuffer[bufferPos] = '\0';
        processLine(inputBuffer);
        bufferPos = 0;
      }
    } else if (bufferPos < INPUT_BUFFER_SIZE - 1) {
      inputBuffer[bufferPos++] = c;
    }
  }
}

// ── Setup / Loop ──────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);

  FastLED.addLeds<SK6812, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(200);

  // Startup blink: 3 flashes of full white so you can confirm FastLED
  // is alive and talking to the strip. If nothing lights up here, check
  // wiring and power before anything else.
  for (int i = 0; i < 3; i++) {
    fill_solid(leds, NUM_LEDS, CRGB::White);
    FastLED.show();
    delay(200);
    fill_solid(leds, NUM_LEDS, CRGB::Black);
    FastLED.show();
    delay(200);
  }

  // Announce identity on startup so TOME can auto-detect this device
  Serial.println("TOME_LIGHT_CONTROLLER_V1");
}

void loop() {
  readSerial();
  updateLEDs();
}
