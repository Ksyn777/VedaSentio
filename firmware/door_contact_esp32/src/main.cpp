#include <Arduino.h>

#include "DoorSensor.h"
#include "EventPublisher.h"
#include "NetworkManager.h"
#include "TimeService.h"

void setup() {
  Serial.begin(115200);

  initDoorSensor();
  initNetwork();
  updateTimeSynchronization();

  Serial.println("[SYSTEM] Monitorowanie drzwi uruchomione.");
}

void loop() {
  updateNetwork();
  updateTimeSynchronization();

  // Zachowujemy dotychczasowe zachowanie:
  // zdarzenia drzwi obslugujemy dopiero, gdy MQTT jest dostepne.
  if (!isMqttConnected()) {
    delay(5);
    return;
  }

  updateHeartbeat();

  DoorEvent event = checkDoor();

  if (event == DOOR_OPENED) {
    if (sendDoorEvent(true)) {
      confirmDoorEvent(event);
    }
  } else if (event == DOOR_CLOSED) {
    if (sendDoorEvent(false)) {
      confirmDoorEvent(event);
    }
  }
}