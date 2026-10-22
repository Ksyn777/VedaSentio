#include "DoorSensor.h"

static const int KONTAKTRON_PIN = 19;
static const unsigned long debounceDelay = 200;

static int confirmedDoorState = -1;
static int lastRawPinState = -1;
static unsigned long lastDebounceTime = 0;

void initDoorSensor() {
  pinMode(KONTAKTRON_PIN, INPUT_PULLUP);
  delay(10);

  int initialReading = digitalRead(KONTAKTRON_PIN);

  lastRawPinState    = initialReading;
  confirmedDoorState = initialReading;
  lastDebounceTime   = millis();

  Serial.print("Czujnik drzwi zainicjalizowany. Stan początkowy: ");
  Serial.println((initialReading == HIGH) ? "OTWARTE" : "ZAMKNIĘTE");
}

DoorEvent checkDoor() {
  int currentReading = digitalRead(KONTAKTRON_PIN);

  // 1. Wykrycie drgnięcia na pinie -> reset stopera
  if (currentReading != lastRawPinState) {
    lastDebounceTime = millis();
    lastRawPinState = currentReading;
  }

  // 2. Weryfikacja stabilności przez min. 200 ms
  if ((millis() - lastDebounceTime) >= debounceDelay) {
    // Sprawdzamy, czy obecny stabilny stan różni się od OSTATNIO ZATWIERDZONEGO
    if (currentReading != confirmedDoorState) {
      if (currentReading == HIGH) {
        return DOOR_OPENED;
      } else {
        return DOOR_CLOSED;
      }
    }
  }

  return DOOR_NO_CHANGE;
}

void confirmDoorEvent(DoorEvent event) {
  if (event == DOOR_OPENED) {
    confirmedDoorState = HIGH;
    Serial.println("[SENSOR] Zdarzenie DOOR_OPENED zatwierdzone.");
  } else if (event == DOOR_CLOSED) {
    confirmedDoorState = LOW;
    Serial.println("[SENSOR] Zdarzenie DOOR_CLOSED zatwierdzone.");
  }
}