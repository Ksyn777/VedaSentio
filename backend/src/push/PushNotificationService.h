#pragma once

#include "../model/Alarm.h"

#include <chrono>
#include <string>
#include <vector>

class PushNotificationService
{
public:
    PushNotificationService(
        std::string database_connection_string,
        std::string service_account_file_path
    );

    void send_alarm_notification(
        const Alarm& alarm
    );

private:
    std::vector<std::string> get_active_tokens_for_home(
        const std::string& home_id
    ) const;

    std::string get_home_name(
        const std::string& home_id
    ) const;

    std::string get_device_name(
        const std::string& home_id,
        const std::string& device_id
    ) const;

    void mark_token_as_inactive(
        const std::string& firebase_cloud_messaging_token
    ) const;

    std::string get_access_token();

    std::string create_service_account_jwt() const;

    bool send_message_to_token(
        const Alarm& alarm,
        const std::string& home_name,
        const std::string& device_name,
        const std::string& firebase_cloud_messaging_token,
        const std::string& access_token
    );

    std::string database_connection_string_;
    std::string firebase_project_id_;
    std::string service_account_email_;
    std::string service_account_private_key_;
    std::string cached_access_token_;
    std::chrono::system_clock::time_point cached_access_token_expires_at_;
};
