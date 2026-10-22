#include <Arduino.h>
#include <WiFi.h>
#include "DoorSensor.h"
#include "secrets.h"
#include <PubSubClient.h>
#include <time.h>

// Deklaracje funkcji
bool connectWIFI(const char* ssid, const char* password);
bool isConnected();
bool connectMQTT();
bool isMQTTConnected();
bool sendHeartbeat();
bool checkTime();
bool synchronizeTime();
bool getUtcTimestamp(char* buffer, size_t bufferSize);
bool sendDoorEvent(bool doorOpen);

WiFiClient espClient;
PubSubClient client(espClient);

// Konfiguracja MQTT i Heartbeat
unsigned long lastHeartbeat = 0;
const unsigned long heartbeatInterval = 30000;
const char* homeId = "home_001";

// Konfiguracja czasu NTP
const char* ntpServer = "pl.pool.ntp.org";
const char* timeZone = "CET-1CEST,M3.5.0,M10.5.0/3";
bool timeSynchronized = false;


// Odmierzanie prób wznawiania połączenia bez delay()
unsigned long lastWifiRetry = 0;
unsigned long lastMqttRetry = 0;

void setup() {
  Serial.begin(115200);

  initDoorSensor();

  // Konfiguracja serwera MQTT tylko raz
  client.setServer(mqtt_server, mqtt_port);

  if (connectWIFI(WIFI_SSID, WIFI_PASSWORD)) {
    timeSynchronized = synchronizeTime();
  }

  Serial.println("System monitorowania drzwi uruchomiony.");
}

void loop() {
  unsigned long now = millis();

  // 1. Utrzymanie Wi-Fi
  if (!isConnected()) {
    if (now - lastWifiRetry >= 5000) {
      lastWifiRetry = now;
      Serial.println("Kolejna próba połączenia z WiFi...");
      if (connectWIFI(WIFI_SSID, WIFI_PASSWORD)) {
        if (!timeSynchronized) {
          timeSynchronized = synchronizeTime();
        }
      }
    }
    return; // Jeśli nie ma Wi-Fi, pomijamy MQTT
  }

  // 2. Utrzymanie MQTT
  if (!isMQTTConnected()) {
    if (now - lastMqttRetry >= 5000) {
      lastMqttRetry = now;
      Serial.println("Kolejna próba połączenia z MQTT...");
      connectMQTT();
    }
    return;
  }

  // 3. Obsługa pętli MQTT
  client.loop();

  // 4. Cykliczny Heartbeat
  if (checkTime()) {
    if (sendHeartbeat()) {
      lastHeartbeat = millis();
    }
  }

  DoorEvent event = checkDoor();

  if (event == DOOR_OPENED) {
    if (sendDoorEvent(true)) {
      confirmDoorEvent(event);
    }
  } 
  else if (event == DOOR_CLOSED) {
    if (sendDoorEvent(false)) {
      confirmDoorEvent(event);
    }
  }

}

bool connectWIFI(const char* ssid, const char* password) {
  if (strlen(ssid) == 0 || strlen(password) == 0) {
    Serial.println("Błąd: Nazwa sieci lub hasło jest puste!");
    return false;
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  int licznik = 0;
  while (WiFi.status() != WL_CONNECTED && licznik < 20) {
    delay(250);
    Serial.print(".");
    licznik++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi połączone");
    Serial.print("Adres IP: ");
    Serial.println(WiFi.localIP());
    return true;
  } else {
    Serial.println("\nPołączenie z Wi-Fi nieudane (Timeout).");
    return false;
  }
}

bool isConnected() {
  return (WiFi.status() == WL_CONNECTED);
}

bool connectMQTT() {
  if (!isConnected()) {
    return false;
  }

  if (client.connect(client_id, mqtt_user, mqtt_password)) {
    Serial.println("Połączono z MQTT pomyślnie.");
    return true;
  } else {
    Serial.print("Błąd połączenia z brokerem! Kod błędu: ");
    Serial.println(client.state());
    return false;
  }
}

bool isMQTTConnected() {
  return client.connected();
}

bool sendHeartbeat() {
  if (!isMQTTConnected()) {
    return false;
  }

  char timestamp[25];
  if (!getUtcTimestamp(timestamp, sizeof(timestamp))) {
    Serial.println("Nie można wysłać MQTT - brak aktualnego czasu UTC!");
    return false;
  }

  char topic[64];
  snprintf(topic, sizeof(topic), "vedasentio/%s/door_001/event", homeId);

  char payload[160];
  snprintf(payload, sizeof(payload), 
           "{\"timestamp\":\"%s\",\"event_type\":\"heartbeat\",\"value\":true}", 
           timestamp);

  if (client.publish(topic, payload)) {
    Serial.println("Heartbeat wysłany pomyślnie!");
    return true;
  } else {
    Serial.println("Błąd publikacji wiadomości Heartbeat!");
    return false;
  }
}

bool checkTime() {
  return (millis() - lastHeartbeat >= heartbeatInterval);
}

bool synchronizeTime() {
  if (!isConnected()) {
    return false;
  }

  configTzTime(timeZone, ntpServer);

  struct tm timeinfo;
  if (!getLocalTime(&timeinfo, 5000)) {
    Serial.println("Błąd: limit czasu NTP przekroczony!");
    return false;
  }

  Serial.println("Zegar ESP32 pomyślnie zsynchronizowany z NTP.");
  return true;
}

bool getUtcTimestamp(char* buffer, size_t bufferSize) {
  time_t now;
  time(&now);

  // Zabezpieczenie: jeśli czas jest wcześniejszy niż rok 2024, zegar nie jest zsynchronizowany
  if (now < 1704067200) {
    return false;
  }

  struct tm timeinfo;
  gmtime_r(&now, &timeinfo); // Konwersja do UTC

  if (strftime(buffer, bufferSize, "%Y-%m-%dT%H:%M:%SZ", &timeinfo) == 0) {
    return false;
  }
  return true;
}

  
bool sendDoorEvent(bool doorOpen) {
  if (!isMQTTConnected()) {
    return false;
  }

  char timestamp[25];
  if (!getUtcTimestamp(timestamp, sizeof(timestamp))) {
    Serial.println("Nie można wysłać eventu drzwi - brak aktualnego czasu UTC!");
    return false;
  }

  const char* eventType = doorOpen ? "door_opened" : "door_closed";
  const char* valueStr  = doorOpen ? "true" : "false";

  char topic[64];
  snprintf(topic, sizeof(topic), "vedasentio/%s/door_001/event", homeId);

  char payload[160];
  snprintf(payload, sizeof(payload), 
           "{\"timestamp\":\"%s\",\"event_type\":\"%s\",\"value\":%s}", 
           timestamp, 
           eventType, 
           valueStr);

  if (client.publish(topic, payload)) {
    Serial.printf("[EVENT] Wysłano [%s]: %s\n", eventType, payload);
    return true;
  } else {
    Serial.println("Błąd publikacji zdarzenia drzwi!");
    return false;
  }
}