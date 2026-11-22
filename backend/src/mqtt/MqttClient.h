#pragma once

#include <mqtt/async_client.h>

#include <string>

class AlarmRepository;
class Database;
class PushNotificationService;

class MqttClient final : public virtual mqtt::callback
{
public:
    MqttClient(
        std::string server_address,
        std::string client_id,
        std::string topic_filter,
        int qos,
        Database& database,
        AlarmRepository& alarms,
        PushNotificationService* push_notifications
    );

    void start(
        const std::string& username,
        const std::string& password
    );

    void connected(
        const std::string& cause
    ) override;

    void connection_lost(
        const std::string& cause
    ) override;

    void message_arrived(
        mqtt::const_message_ptr message
    ) override;

private:
    std::string server_address_;
    std::string topic_filter_;
    int qos_;
    Database& database_;
    AlarmRepository& alarms_;
    PushNotificationService* push_notifications_;
    mqtt::async_client client_;
};
