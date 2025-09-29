void setup() {
  Serial.begin(9600);

  pinMode(13, INPUT_PULLUP); // D7
  pinMode(12, INPUT_PULLUP); // D6
}

bool isFocused = false;

void loop() {
  if (digitalRead(13) == LOW) {
    if (isFocused == false) {
      Serial.println("button1"); //focus on
    }
    isFocused = true;
    delay(100);
  }
  if (digitalRead(12) == LOW) {
    if (isFocused == true) {
      Serial.println("button2"); //focus off
    }
    isFocused = false;
    delay(100);
  }
}
