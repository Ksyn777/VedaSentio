#include "MqttClient.h"

#include "../database/Database.h"
#include "../model/SensorEvent.h"

#include <nlohmann/json.hpp>

#include <iostream>
#include <sstream>
#include <stdexcept>
#include <utility>
#include <vector>

namespace
{
std::vector<std::string> split_topic(
    const std::string& topic
)
{
    std::vector<std::string> parts;
    std::stringstream stream(topic);
    std::string part;

    while (std::getline(stream, part, '/'))
    {
        parts.push_back(part);
    }

    return parts;
}

SensorEvent parse_sensor_event(
    const std::string& topic,
    const std::string& payload
)
{
    // Expected topic:
    // vedasentio/{home_id}/{device_id}/event
    const auto topic_parts = split_topic(topic);

    if (topic_parts.size() != 4 ||
        topic_parts[0] != "vedasentio" ||
        topic_parts[3] != "event" ||
        topic_parts[1].empty() ||
        topic_parts[2].empty())
    {
        throw std::runtime_error(
            "Invalid MQTT topic. Expected: "
            "vedasentio/{home_id}/{device_id}/event"
        );
    }

    const auto json =
        nlohmann::json::parse(payload);

    if (!json.contains("event_type") ||
        !json["event_type"].is_string())
    {
        throw std::runtime_error(
            "Payload field 'event_type' is required "
            "and must be a string."
        );
    }

    if (!json.contains("value"))
    {
        throw std::runtime_error(
            "Payload field 'value' is required."
        );
    }

    if (!json.contains("timestamp") ||
        !json["timestamp"].is_string())
    {
        throw std::runtime_error(
            "Payload field 'timestamp' is required "
            "and must be a string."
        );
    }

    SensorEvent event;
    event.topic = topic;
    event.home_id = topic_parts[1];
    event.device_id = topic_parts[2];
    event.event_type =
        json["event_type"].get<std::string>();
    event.value_json =
        json["value"].dump();
    event.device_timestamp =
        json["timestamp"].get<std::string>();
    event.raw_payload = payload;

    return event;
}
}

MqttClient::MqttClient(
    std::string server_address,
    std::string client_id,
    std::string topic_filter,
    int qos,
    Database& database
)
    : server_address_(std::move(server_address)),
      topic_filter_(std::move(topic_filter)),
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

    client_.subscribe(
        topic_filter_,
        qos_
    )->wait();

    std::cout << "[MQTT] Subscribed: "
              << topic_filter_
              << '\n';
}

void MqttClient::connection_lost(
    const std::string& cause
)
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
    const std::string topic =
        message->get_topic();

    const std::string payload =
        message->to_string();

    std::cout << "\n[MQTT] Message received\n";
    std::cout << "Topic:   "
              << topic
              << '\n';
    std::cout << "Payload: "
              << payload
              << '\n';

    try
    {
        const SensorEvent event =
            parse_sensor_event(
                topic,
                payload
            );

        std::cout << "[EVENT] home_id="
                  << event.home_id
                  << " device_id="
                  << event.device_id
                  << " event_type="
                  << event.event_type
                  << '\n';

        database_.validate_device(
            event.home_id,
            event.device_id
        );

        std::cout << "[DEVICE] Registered and active.\n";

        database_.save_event(event);
    }
    catch (const nlohmann::json::exception& error)
    {
        std::cerr
            << "[JSON] Invalid payload: "
            << error.what()
            << '\n';
    }
    catch (const std::exception& error)
    {
        std::cerr
            << "[EVENT] Rejected: "
            << error.what()
            << '\n';
    }
}
