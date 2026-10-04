#pragma once

#include <string>

struct SensorEvent
{
    std::string topic;
    std::string home_id;
    std::string device_id;
    std::string event_type;
    std::string value_json;
    std::string device_timestamp;
    std::string raw_payload;
};
