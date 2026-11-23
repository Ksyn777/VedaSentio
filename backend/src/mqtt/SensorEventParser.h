#pragma once

#include "../model/SensorEvent.h"

#include <string>

SensorEvent parse_sensor_event(
    const std::string& topic,
    const std::string& payload
);
