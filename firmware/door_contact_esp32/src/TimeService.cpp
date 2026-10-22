#include "TimeService.h"

#include <time.h>

#include "NetworkManager.h"

namespace {
const char* NTP_SERVER = "pl.pool.ntp.org";
const char* TIME_ZONE = "CET-1CEST,M3.5.0,M10.5.0/3";

bool synchronized = false;
unsigned long lastSyncAttempt = 0;

constexpr unsigned long TIME_RETRY_INTERVAL = 10000;

bool synchronizeTime() {
  if (!isWifiConnected()) {
    return false;
  }

  configTzTime(TIME_ZONE, NTP_SERVER);

  struct tm timeInfo;
  if (!getLocalTime(&timeInfo, 5000)) {
    Serial.println("[TIME] Synchronizacja NTP nieudana.");
    return false;
  }

  Serial.println("[TIME] Zegar zsynchronizowany z NTP.");
  return true;
}
}

void updateTimeSynchronization() {
  if (synchronized || !isWifiConnected()) {
    return;
  }

  const unsigned long now = millis();

  if (lastSyncAttempt != 0 && now - lastSyncAttempt < TIME_RETRY_INTERVAL) {
    return;
  }

  lastSyncAttempt = now;
  synchronized = synchronizeTime();
}

bool isTimeSynchronized() {
  return synchronized;
}

bool getUtcTimestamp(char* buffer, size_t bufferSize) {
  time_t now;
  time(&now);

  // 2024-01-01T00:00:00Z - ochrona przed uzyciem niezainicjalizowanego zegara.
  if (now < 1704067200) {
    return false;
  }

  struct tm timeInfo;
  gmtime_r(&now, &timeInfo);

  return strftime(buffer, bufferSize, "%Y-%m-%dT%H:%M:%SZ", &timeInfo) != 0;
}