// ESP32 + TMC2209 V1.3 - Basic Test
// Just spins the motor to verify connections
// All pins on LEFT side of ESP32 board

#define DIR_PIN   14  // D14 (LEFT side)
#define EN_PIN    26  // D26 (LEFT side)
#define STEP_PIN  27  // D27 (LEFT side)

// Speed control (lower = faster, higher = slower)
// Range: 100-5000 microseconds recommended
int SPEED = 70;  // Default speed (microseconds between steps)

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=== TMC2209 Basic Motor Test ===");
  
  pinMode(DIR_PIN, OUTPUT);
  pinMode(EN_PIN, OUTPUT);
  pinMode(STEP_PIN, OUTPUT);
  
  digitalWrite(EN_PIN, LOW);   // Enable driver
  digitalWrite(DIR_PIN, LOW);
  digitalWrite(STEP_PIN, LOW);
  
  Serial.println("Motor enabled!");
  Serial.print("Speed: ");
  Serial.print(SPEED);
  Serial.println(" μs between steps");
  Serial.println("Starting rotation test...\n");
}

void loop() {
  // Clockwise - 1 full revolution
  Serial.println("→ Clockwise (1 full revolution)");
  digitalWrite(DIR_PIN, LOW);
  for(int i = 0; i < 3200; i++) {
    digitalWrite(STEP_PIN, HIGH);
    delayMicroseconds(SPEED);
    digitalWrite(STEP_PIN, LOW);
    delayMicroseconds(SPEED);
  }
  delay(1000);
  
  // Counter-clockwise - 1 full revolution
  Serial.println("← Counter-clockwise (1 full revolution)");
  digitalWrite(DIR_PIN, HIGH);
  for(int i = 0; i < 3200; i++) {
    digitalWrite(STEP_PIN, HIGH);
    delayMicroseconds(SPEED);
    digitalWrite(STEP_PIN, LOW);
    delayMicroseconds(SPEED);
  }
  delay(1000);
}