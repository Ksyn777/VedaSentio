#pragma once
#include <string>
struct Device {
    std::string home_id;
    std::string id;
    std::string device_type;
    std::string name;
    bool is_active;
    std::string created_at;
};
