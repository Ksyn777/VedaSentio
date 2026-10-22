#include "NetworkManager.h"

#include <Arduino.h>
#include <WiFi.h>

#include "secrets.h"

namespace {
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

unsigned long lastWifiRetry = 0;
unsigned long lastMqttRetry = 0;

constexpr unsigned long WIFI_RETRY_INTERVAL = 5000;
constexpr unsigned long MQTT_RETRY_INTERVAL = 5000;

bool connectWifi() {
  if (strlen(WIFI_SSID) == 0 || strlen(WIFI_PASSWORD) == 0) {
    Serial.println("[WIFI] Blad: nazwa sieci lub haslo jest puste.");
    return false;
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("[WIFI] Laczenie");

  int counter = 0;
  while (WiFi.status() != WL_CONNECTED && counter < 20) {
    delay(250);
    Serial.print(".");
    counter++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("[WIFI] Polaczono.");
    Serial.print("[WIFI] Adres IP: ");
    Serial.println(WiFi.localIP());
    return true;
  }

  Serial.println();
  Serial.println("[WIFI] Polaczenie nieudane (timeout).");
  return false;
}

bool connectMqtt() {
  if (!isWifiConnected()) {
    return false;
  }

  if (mqttClient.connect(client_id, mqtt_user, mqtt_password)) {
    Serial.println("[MQTT] Polaczono z brokerem.");
    return true;
  }

  Serial.print("[MQTT] Blad polaczenia. Kod: ");
  Serial.println(mqttClient.state());
  return false;
}
}

void initNetwork() {
  mqttClient.setServer(mqtt_server, mqtt_port);

  if (connectWifi()) {
    connectMqtt();
  }
}

void updateNetwork() {
  const unsigned long now = millis();

  if (!isWifiConnected()) {
    if (now - lastWifiRetry >= WIFI_RETRY_INTERVAL) {
      lastWifiRetry = now;
      Serial.println("[WIFI] Ponowna proba polaczenia...");
      connectWifi();
    }
    return;
  }

  if (!isMqttConnected()) {
    if (now - lastMqttRetry >= MQTT_RETRY_INTERVAL) {
      lastMqttRetry = now;
      Serial.println("[MQTT] Ponowna proba polaczenia...");
      connectMqtt();
    }
    return;
  }

  mqttClient.loop();
}

bool isWifiConnected() {
  return WiFi.status() == WL_CONNECTED;
}

bool isMqttConnected() {
  return mqttClient.connected();
}

PubSubClient& getMqttClient() {
  return mqttClient;
}