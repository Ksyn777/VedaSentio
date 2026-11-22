#include "SensorEventParser.h"

#include <nlohmann/json.hpp>

#include <array>
#include <cctype>
#include <sstream>
#include <stdexcept>
#include <string_view>
#include <vector>

namespace
{
constexpr std::size_t MAX_PAYLOAD_SIZE = 4096;
constexpr std::size_t MAX_ID_LENGTH = 64;

const std::array<std::string_view, 13> SUPPORTED_EVENT_TYPES = {
    "heartbeat",
    "door_opened",
    "door_closed",
    "sos_pressed",
    "sos_resolved",
    "smoke_detected",
    "smoke_cleared",
    "co_detected",
    "co_cleared",
    "gas_detected",
    "gas_cleared",
    "flood_detected",
    "flood_cleared"
};

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

bool is_valid_id(
    const std::string& value
)
{
    if (
        value.empty() ||
        value.size() > MAX_ID_LENGTH
    )
    {
        return false;
    }

    for (const unsigned char character : value)
    {
        if (
            !std::isalnum(character) &&
            character != '_' &&
            character != '-'
        )
        {
            return false;
        }
    }

    return true;
}

bool is_supported_event_type(
    const std::string& event_type
)
{
    for (const std::string_view supported : SUPPORTED_EVENT_TYPES)
    {
        if (event_type == supported)
        {
            return true;
        }
    }

    return false;
}

bool expected_boolean_value(
    const std::string& event_type
)
{
    return
        event_type == "heartbeat" ||
        event_type == "door_opened" ||
        event_type == "sos_pressed" ||
        event_type == "smoke_detected" ||
        event_type == "co_detected" ||
        event_type == "gas_detected" ||
        event_type == "flood_detected";
}

int parse_two_digits(
    const std::string& text,
    std::size_t position
)
{
    return
        (text[position] - '0') * 10 +
        (text[position + 1] - '0');
}

bool is_digit_range(
    const std::string& text,
    std::size_t begin,
    std::size_t end
)
{
    for (std::size_t index = begin; index < end; ++index)
    {
        if (!std::isdigit(static_cast<unsigned char>(text[index])))
        {
            return false;
        }
    }

    return true;
}

bool is_valid_utc_timestamp(
    const std::string& timestamp
)
{
    if (
        timestamp.size() < 20 ||
        timestamp.size() > 32 ||
        timestamp[4] != '-' ||
        timestamp[7] != '-' ||
        timestamp[10] != 'T' ||
        timestamp[13] != ':' ||
        timestamp[16] != ':' ||
        timestamp.back() != 'Z'
    )
    {
        return false;
    }

    if (
        !is_digit_range(timestamp, 0, 4) ||
        !is_digit_range(timestamp, 5, 7) ||
        !is_digit_range(timestamp, 8, 10) ||
        !is_digit_range(timestamp, 11, 13) ||
        !is_digit_range(timestamp, 14, 16) ||
        !is_digit_range(timestamp, 17, 19)
    )
    {
        return false;
    }

    const int month = parse_two_digits(timestamp, 5);
    const int day = parse_two_digits(timestamp, 8);
    const int hour = parse_two_digits(timestamp, 11);
    const int minute = parse_two_digits(timestamp, 14);
    const int second = parse_two_digits(timestamp, 17);

    if (
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour > 23 ||
        minute > 59 ||
        second > 59
    )
    {
        return false;
    }

    if (timestamp.size() == 20)
    {
        return true;
    }

    if (
        timestamp[19] != '.' ||
        timestamp.size() < 22
    )
    {
        return false;
    }

    return is_digit_range(
        timestamp,
        20,
        timestamp.size() - 1
    );
}
}

SensorEvent parse_sensor_event(
    const std::string& topic,
    const std::string& payload
)
{
    if (payload.size() > MAX_PAYLOAD_SIZE)
    {
        throw std::runtime_error(
            "MQTT payload is too large."
        );
    }

    const auto topic_parts =
        split_topic(topic);

    if (
        topic_parts.size() != 4 ||
        topic_parts[0] != "vedasentio" ||
        topic_parts[3] != "event" ||
        !is_valid_id(topic_parts[1]) ||
        !is_valid_id(topic_parts[2])
    )
    {
        throw std::runtime_error(
            "Invalid MQTT topic. Expected: "
            "vedasentio/{home_id}/{device_id}/event"
        );
    }

    const auto json =
        nlohmann::json::parse(payload);

    if (!json.is_object())
    {
        throw std::runtime_error(
            "MQTT payload must be a JSON object."
        );
    }

    if (
        !json.contains("event_type") ||
        !json["event_type"].is_string()
    )
    {
        throw std::runtime_error(
            "Payload field 'event_type' is required "
            "and must be a string."
        );
    }

    const std::string event_type =
        json["event_type"].get<std::string>();

    if (!is_supported_event_type(event_type))
    {
        throw std::runtime_error(
            "Unsupported event_type."
        );
    }

    if (
        !json.contains("value") ||
        !json["value"].is_boolean()
    )
    {
        throw std::runtime_error(
            "Payload field 'value' is required "
            "and must be a boolean."
        );
    }

    const bool value =
        json["value"].get<bool>();

    if (value != expected_boolean_value(event_type))
    {
        throw std::runtime_error(
            "Payload field 'value' does not match event_type."
        );
    }

    if (
        !json.contains("timestamp") ||
        !json["timestamp"].is_string()
    )
    {
        throw std::runtime_error(
            "Payload field 'timestamp' is required "
            "and must be a string."
        );
    }

    const std::string timestamp =
        json["timestamp"].get<std::string>();

    if (!is_valid_utc_timestamp(timestamp))
    {
        throw std::runtime_error(
            "Payload field 'timestamp' must use UTC ISO-8601 format."
        );
    }

    SensorEvent event;

    event.topic = topic;
    event.home_id = topic_parts[1];
    event.device_id = topic_parts[2];
    event.event_type = event_type;
    event.value_json = json["value"].dump();
    event.device_timestamp = timestamp;
    event.raw_payload = payload;

    return event;
}
