#include <Arduino.h>
#include <PicoMQTT.h>
#include "mqtt.h"

static PicoMQTT::Client mqtt("broker.emqx.io");
static String received;

void mqttBegin() {
  mqtt.subscribe("qnis/teste", [](const char* payload) { received = payload; });
  mqtt.begin();
}

String mqttLoop() {
  mqtt.loop();

  String msg = received;
  received = "";
  return msg;  // vazio se não chegou nada
}
