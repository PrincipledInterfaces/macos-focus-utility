const int sensorPin = A0;  // LDR voltage divider
int threshold = 1000;       // adjust after testing

void setup() {
  Serial.begin(9600);
}

void loop() {
  int sensorValue = analogRead(sensorPin);
  //Serial.println(sensorValue);
  if (sensorValue < threshold) { // beam broken
    Serial.println("button1"); // focus on
    delay(600);
  }
}
