#include <Arduino.h>
#include "wifi.h"
#include "mqtt.h"

const int LED_PIN = 12;

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  connectWifi();
  mqtt.connect();
}

void loop() {
  String msg = mqtt.waitMessage();

  if (msg == "turn on") digitalWrite(LED_PIN, HIGH);
  else if (msg == "turn off") digitalWrite(LED_PIN, LOW);
}
