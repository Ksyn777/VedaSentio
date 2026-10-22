#ifndef DOOR_SENSOR_H
#define DOOR_SENSOR_H

#include <Arduino.h>

enum DoorEvent {
  DOOR_NO_CHANGE = 0, // brak zmiany
  DOOR_OPENED    = 1, // wykryto stabilne otwarcie
  DOOR_CLOSED    = 2  // wykryto stabilne zamknięcie
};

// Inicjalizacja pinu i stanów początkowych
void initDoorSensor();

// Sprawdzenie stanu (zwraca zdarzenie, ale NIE zatwierdza go wewnętrznie)
DoorEvent checkDoor();

// Zatwierdzenie obsłużenia zdarzenia (np. po udanym wysłaniu przez MQTT)
void confirmDoorEvent(DoorEvent event);

#endif