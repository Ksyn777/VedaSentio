#pragma once

#include "../model/Device.h"
#include "../model/EventRecord.h"
#include "../model/Home.h"
#include "../model/SensorEvent.h"

#include <optional>
#include <string>
#include <vector>

class Database
{
public:
    explicit Database(std::string connection_string);

    void test_connection() const;

    void validate_device(
        const std::string& home_id,
        const std::string& device_id
    ) const;

    void update_device_last_seen(
        const std::string& home_id,
        const std::string& device_id
    ) const;

    long long save_event(
        const SensorEvent& event
    ) const;

    std::vector<Home> get_homes() const;

    std::vector<Device> get_devices(
        const std::string& home_id
    ) const;

    std::vector<EventRecord> get_events(
        const std::string& home_id,
        int limit = 100
    ) const;

    std::optional<EventRecord> get_latest_event(
        const std::string& home_id,
        const std::string& device_id
    ) const;

    void save_mobile_push_notification_token(
        long long user_id,
        const std::string& firebase_cloud_messaging_token,
        const std::string& mobile_platform
    ) const;

private:
    std::string connection_string_;
};
