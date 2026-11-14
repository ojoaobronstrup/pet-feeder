#include <WiFi.h>
#include "secrets.h"

void connectWifi() {
    WiFi.begin(WIFI_SSID, WIFI_PASS);

    if (WiFi.waitForConnectResult() != WL_CONNECTED) {
        Serial.println("Erro ao conectar WiFi");
    };
};
