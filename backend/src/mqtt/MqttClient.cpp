#include "MqttClient.h"

#include "../database/Database.h"

#include <iostream>
#include <utility>

MqttClient::MqttClient(
    std::string server_address,
    std::string client_id,
    std::string topic,
    int qos,
    Database& database
)
    : server_address_(std::move(server_address)),
      topic_(std::move(topic)),
      qos_(qos),
      database_(database),
      client_(server_address_, std::move(client_id))
{
    client_.set_callback(*this);
}

void MqttClient::start(
    const std::string& username,
    const std::string& password
)
{
    auto connection_options =
        mqtt::connect_options_builder()
            .user_name(username)
            .password(password)
            .clean_session(true)
            .finalize();

    std::cout << "[MQTT] Connecting to "
              << server_address_
              << "...\n";

    client_.connect(connection_options)->wait();

    std::cout << "[MQTT] Connected.\n";

    client_.subscribe(topic_, qos_)->wait();

    std::cout << "[MQTT] Subscribed: "
              << topic_
              << '\n';
}

void MqttClient::connection_lost(const std::string& cause)
{
    std::cerr << "[MQTT] Connection lost";

    if (!cause.empty())
    {
        std::cerr << ": " << cause;
    }

    std::cerr << '\n';
}

void MqttClient::message_arrived(
    mqtt::const_message_ptr message
)
{
    const std::string topic = message->get_topic();
    const std::string payload = message->to_string();

    std::cout << "\n[MQTT] Message received\n";
    std::cout << "Topic:   " << topic << '\n';
    std::cout << "Message: " << payload << '\n';

    try
    {
        database_.save_event(topic, payload);
    }
    catch (const std::exception& error)
    {
        std::cerr << "[DB] Error: "
                  << error.what()
                  << '\n';
    }
}
