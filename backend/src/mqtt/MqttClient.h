#pragma once

#include <mqtt/async_client.h>

#include <string>

class Database;

class MqttClient final : public virtual mqtt::callback
{
public:
    MqttClient(
        std::string server_address,
        std::string client_id,
        std::string topic,
        int qos,
        Database& database
    );

    void start(
        const std::string& username,
        const std::string& password
    );

    void connection_lost(const std::string& cause) override;

    void message_arrived(
        mqtt::const_message_ptr message
    ) override;

private:
    std::string server_address_;
    std::string topic_;
    int qos_;

    Database& database_;
    mqtt::async_client client_;
};
