#include <Arduino.h>
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFi.h>

#if __has_include("secrets.h")
#include "secrets.h"
#endif

#ifndef WIFI_SSID
#define WIFI_SSID ""
#endif
#ifndef WIFI_PASS
#define WIFI_PASS ""
#endif
#ifndef FEEDER_API_URL
#define FEEDER_API_URL ""
#endif
#ifndef FEEDER_DEVICE_KEY
#define FEEDER_DEVICE_KEY ""
#endif
#ifndef FEEDER_LED_PIN
#define FEEDER_LED_PIN 23
#endif

namespace {
constexpr uint32_t pollIntervalMs = 1000;
constexpr uint32_t contactTimeoutMs = 15000;
constexpr uint32_t maxPulseMs = 10000;
constexpr uint16_t httpTimeoutMs = 1000;

struct Command {
  bool active;
  int64_t revision;
  uint32_t pulseMs;
};

bool configured = false;
bool active = false;
bool hasAppliedCommand = false;
int64_t appliedRevision = 0;
uint32_t lastPollAt = 0;
uint32_t lastContactAt = 0;
uint32_t pulseStartedAt = 0;
uint32_t pulseDurationMs = 0;
bool apiAvailable = false;

void setLed(bool on) {
  digitalWrite(FEEDER_LED_PIN, on ? HIGH : LOW);
  active = on;
}

void enforceLedTimeouts(uint32_t now) {
  if (pulseDurationMs != 0 && now - pulseStartedAt >= pulseDurationMs) {
    pulseDurationMs = 0;
    setLed(false);
  }

  if (active && now - lastContactAt >= contactTimeoutMs) {
    pulseDurationMs = 0;
    setLed(false);
  }
}

bool pollApi(Command& command) {
  WiFiClient connection;
  HTTPClient http;
  if (!http.begin(connection, FEEDER_API_URL "/api/device/poll")) {
    return false;
  }

  http.useHTTP10(true);
  http.setConnectTimeout(httpTimeoutMs);
  http.setTimeout(httpTimeoutMs);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " FEEDER_DEVICE_KEY);

  JsonDocument request;
  request["active"] = active;
  request["appliedRevision"] = appliedRevision;
  String body;
  serializeJson(request, body);

  const int status = http.POST(body);
  if (status != HTTP_CODE_OK) {
    http.end();
    return false;
  }

  JsonDocument response;
  const auto error = deserializeJson(response, http.getStream());
  http.end();

  if (error || !response["active"].is<bool>() ||
      !response["revision"].is<int64_t>() ||
      !response["pulseMs"].is<uint32_t>()) {
    return false;
  }

  command.active = response["active"].as<bool>();
  command.revision = response["revision"].as<int64_t>();
  command.pulseMs = response["pulseMs"].as<uint32_t>();
  return command.revision >= 0 && command.pulseMs <= maxPulseMs &&
         (command.active || command.pulseMs == 0);
}

void applyCommand(const Command& command, uint32_t now) {
  const bool newRevision = !hasAppliedCommand || command.revision != appliedRevision;
  if (command.pulseMs == 0) {
    pulseDurationMs = 0;
    setLed(command.active);
  } else if (newRevision) {
    pulseStartedAt = now;
    pulseDurationMs = command.pulseMs;
    setLed(true);
  }

  appliedRevision = command.revision;
  hasAppliedCommand = true;
}
}  // namespace

void setup() {
  Serial.begin(115200);
  pinMode(FEEDER_LED_PIN, OUTPUT);
  setLed(false);

  configured = WIFI_SSID[0] != '\0' && FEEDER_API_URL[0] != '\0' &&
               FEEDER_DEVICE_KEY[0] != '\0';
  if (!configured) {
    Serial.println("Configure o Wi-Fi, a URL e a chave em include/secrets.h.");
    return;
  }

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.println("Conectando o alimentador ao Wi-Fi.");
}

void loop() {
  const uint32_t now = millis();
  enforceLedTimeouts(now);

  if (configured && now - lastPollAt >= pollIntervalMs) {
    lastPollAt = now;
    Command command{};
    const bool received = WiFi.status() == WL_CONNECTED && pollApi(command);
    const uint32_t completedAt = millis();
    enforceLedTimeouts(completedAt);

    if (received != apiAvailable) {
      apiAvailable = received;
      Serial.println(received ? "API conectada." : "Sem resposta da API.");
    }

    if (received) {
      lastContactAt = completedAt;
      applyCommand(command, completedAt);
    }
  }

  delay(10);
}
