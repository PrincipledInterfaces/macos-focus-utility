bool phoneCharging = false;
bool go = false;

void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);
  pinMode(4, INPUT);
  delay(2500);
  Serial.println("Now looking for phone...");
  go = true;
}

void loop() {
  // put your main code here, to run repeatedly:
  if (go == true) {
    if (digitalRead(4)==HIGH && phoneCharging == false) {
      phoneCharging = true;
      Serial.println("Phone present.");
    } else if (digitalRead(4)==LOW && phoneCharging == true){
      phoneCharging = false;
      Serial.println("No phone present.");
    }
  }
}
