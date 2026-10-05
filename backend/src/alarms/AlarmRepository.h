#pragma once

#include "../model/Alarm.h"
#include "../model/SensorEvent.h"

#include <optional>
#include <string>
#include <vector>

class AlarmRepository
{
public:
    explicit AlarmRepository(
        std::string connection_string
    );

    void process_event(
        const SensorEvent& event,
        long long event_id
    ) const;

    std::vector<Alarm> get_alarms(
        const std::string& home_id,
        bool active_only,
        int limit = 100
    ) const;

    std::optional<Alarm> acknowledge_alarm(
        const std::string& home_id,
        long long alarm_id,
        long long user_id
    ) const;

private:
    std::string connection_string_;
};
