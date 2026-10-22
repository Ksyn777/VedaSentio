#include "EventPublisher.h"

#include <Arduino.h>

#include "NetworkManager.h"
#include "TimeService.h"

namespace {
const char* HOME_ID = "home_001";
const char* DEVICE_ID = "door_001";

unsigned long lastHeartbeat = 0;
constexpr unsigned long HEARTBEAT_INTERVAL = 30000;

bool publishEvent(const char* eventType, const char* valueJson) {
  if (!isMqttConnected()) {
    return false;
  }

  char timestamp[25];
  if (!getUtcTimestamp(timestamp, sizeof(timestamp))) {
    Serial.println("[EVENT] Brak poprawnego czasu UTC - publikacja pominieta.");
    return false;
  }

  char topic[64];
  snprintf(
      topic,
      sizeof(topic),
      "vedasentio/%s/%s/event",
      HOME_ID,
      DEVICE_ID);

  char payload[160];
  snprintf(
      payload,
      sizeof(payload),
      "{\"timestamp\":\"%s\",\"event_type\":\"%s\",\"value\":%s}",
      timestamp,
      eventType,
      valueJson);

  if (getMqttClient().publish(topic, payload)) {
    Serial.printf("[EVENT] Wyslano [%s]: %s\n", eventType, payload);
    return true;
  }

  Serial.printf("[EVENT] Blad publikacji [%s].\n", eventType);
  return false;
}
}

void updateHeartbeat() {
  if (millis() - lastHeartbeat < HEARTBEAT_INTERVAL) {
    return;
  }

  if (publishEvent("heartbeat", "true")) {
    lastHeartbeat = millis();
    Serial.println("[HEARTBEAT] Wyslano pomyslnie.");
  }
}

bool sendDoorEvent(bool doorOpen) {
  return publishEvent(
      doorOpen ? "door_opened" : "door_closed",
      doorOpen ? "true" : "false");
}