#ifndef NETWORK_MANAGER_H
#define NETWORK_MANAGER_H

#include <PubSubClient.h>

void initNetwork();
void updateNetwork();

bool isWifiConnected();
bool isMqttConnected();

PubSubClient& getMqttClient();

#endif