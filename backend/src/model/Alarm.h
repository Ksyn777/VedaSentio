#pragma once

#include <optional>
#include <string>

struct Alarm
{
    long long id = 0;

    std::string home_id;
    std::string device_id;

    std::string alarm_type;
    std::string severity;
    std::string status;

    std::optional<long long> source_event_id;
    std::optional<long long> last_event_id;

    std::string started_at;

    std::string acknowledged_at;
    std::optional<long long> acknowledged_by;

    std::string resolved_at;
    std::optional<long long> resolved_by;
    std::string resolution_source;

    std::string created_at;
    std::string updated_at;
};
