/*
  Used "Arduino LSM9DS1 - Simple Gyroscope" example code by Riccardo Rizzo as a starting point.
*/

#include <Arduino_LSM9DS1.h>
#include <Arduino_APDS9960.h>

int resetButtonPIN = 10;
int clickButtonPIN = 9;

void setup() {
  pinMode(resetButtonPIN, INPUT_PULLUP);
  pinMode(clickButtonPIN, INPUT_PULLUP);
  Serial.begin(9600);
  while (!Serial);

  if (!IMU.begin()) {
    while (1);
  }
  if(!APDS.begin()) {
    while(1);
  }
}

PinStatus lastClick = LOW;

void loop() {
  float x, y, z;

  if(digitalRead(resetButtonPIN) != HIGH) {
    // write reset button pressed
    Serial.write((uint8_t)1);
  }

  PinStatus currentClick = digitalRead(clickButtonPIN);
  if(currentClick == HIGH && lastClick == LOW) {
    // write click release
    Serial.write((uint8_t)3);
  } else if(currentClick == LOW && lastClick == HIGH) {
    // write click press
    Serial.write((uint8_t)2);
  }
  lastClick = currentClick;

  if (IMU.gyroscopeAvailable()) {
    IMU.readGyroscope(x, y, z);

    // write gyroscope update
    Serial.write((uint8_t)0);
    Serial.write(reinterpret_cast<uint8_t*>(&x), sizeof(float));
    Serial.write(reinterpret_cast<uint8_t*>(&y), sizeof(float));
    Serial.write(reinterpret_cast<uint8_t*>(&z), sizeof(float));
  }

  if(APDS.gestureAvailable()) {
    switch(APDS.readGesture()) {
      case GESTURE_UP:
        // write scroll up update
        Serial.write((uint8_t)4);
        break;
      case GESTURE_DOWN:
        // write scroll down update
        Serial.write((uint8_t)5);
        break;
      default:
        break;
    }
  }
}
