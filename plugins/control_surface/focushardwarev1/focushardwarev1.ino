void setup() {
  Serial.begin(9600);

  pinMode(15, INPUT_PULLUP); // D8
  pinMode(13, INPUT_PULLUP); // D7
  pinMode(12, INPUT_PULLUP); // D6
}

void loop() {
  if (digitalRead(15) == HIGH) {
    Serial.println("button3");
    delay(1000);
  }
  if (digitalRead(13) == LOW) {
    Serial.println("button1");
    delay(1000);
  }
  if (digitalRead(12) == LOW) {
    Serial.println("button2");
    delay(1000);
  }
}
