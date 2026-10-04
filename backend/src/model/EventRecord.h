#pragma once
#include <string>
struct EventRecord {
    long long id;
    std::string home_id;
    std::string device_id;
    std::string event_type;
    std::string value_json;
    std::string device_timestamp;
    std::string received_at;
};
