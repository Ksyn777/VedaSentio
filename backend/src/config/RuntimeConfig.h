#pragma once


#include <cstdlib>
#include <optional>
#include <stdexcept>
#include <string>


inline int parse_service_port(std::optional<std::string> value, int fallback, const char* name)
{
    if (!value) return fallback;
    int port = 0;
    const auto text = *value;
    const auto invalid = [&]() { throw std::runtime_error(std::string(name) + " must be an integer in range 1-65535"); };
    if (text.empty()) invalid();
    for (const char digit : text) {
        if (digit < '0' || digit > '9' || port > 6553) invalid();
        port = port * 10 + (digit - '0');
        if (port > 65535) invalid();
    }
    if (port == 0) invalid();
    return port;
}

struct RuntimeConfig
{
    int mqtt_port;
    int api_port;

    static RuntimeConfig from_environment()
    {
        const auto read = [](const char* name, int fallback) {
            const char* value = std::getenv(name);
            return parse_service_port(value ? std::optional<std::string>(value) : std::nullopt, fallback, name);
        };
        return {read("VEDASENTIO_MQTT_PORT", 1883), read("VEDASENTIO_API_PORT", 8080)};
    }

    std::string mqtt_address() const { return "tcp://127.0.0.1:" + std::to_string(mqtt_port); }
};

