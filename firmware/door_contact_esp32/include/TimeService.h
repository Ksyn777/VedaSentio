#ifndef TIME_SERVICE_H
#define TIME_SERVICE_H

#include <Arduino.h>

void updateTimeSynchronization();
bool isTimeSynchronized();
bool getUtcTimestamp(char* buffer, size_t bufferSize);

#endif