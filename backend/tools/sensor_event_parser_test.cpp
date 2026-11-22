#include "../src/mqtt/SensorEventParser.h"

#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>

namespace
{
void require(
    bool condition,
    const std::string& message
)
{
    if (!condition)
    {
        throw std::runtime_error(message);
    }
}

void expect_rejected(
    const std::string& topic,
    const std::string& payload
)
{
    bool rejected = false;

    try
    {
        (void)parse_sensor_event(
            topic,
            payload
        );
    }
    catch (const std::exception&)
    {
        rejected = true;
    }

    require(
        rejected,
        "Expected message to be rejected."
    );
}
}

int main()
{
    try
    {
        const SensorEvent heartbeat =
            parse_sensor_event(
                "vedasentio/home_001/door_001/event",
                R"({"timestamp":"2026-11-22T08:30:00Z","event_type":"heartbeat","value":true})"
            );

        require(
            heartbeat.home_id == "home_001",
            "home_id parsing failed."
        );

        require(
            heartbeat.device_id == "door_001",
            "device_id parsing failed."
        );

        require(
            heartbeat.event_type == "heartbeat",
            "event_type parsing failed."
        );

        const SensorEvent door_closed =
            parse_sensor_event(
                "vedasentio/home_001/door_001/event",
                R"({"timestamp":"2026-11-22T08:30:00.125Z","event_type":"door_closed","value":false})"
            );

        require(
            door_closed.value_json == "false",
            "door_closed value parsing failed."
        );

        expect_rejected(
            "wrong/home_001/door_001/event",
            R"({"timestamp":"2026-11-22T08:30:00Z","event_type":"heartbeat","value":true})"
        );

        expect_rejected(
            "vedasentio/home 001/door_001/event",
            R"({"timestamp":"2026-11-22T08:30:00Z","event_type":"heartbeat","value":true})"
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            R"({"timestamp":"2026-11-22T08:30:00Z","event_type":"unknown_event","value":true})"
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            R"({"timestamp":"2026-11-22T08:30:00Z","event_type":"door_opened","value":false})"
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            R"({"timestamp":"2026-11-22T08:30:00Z","event_type":"door_closed","value":"false"})"
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            R"({"timestamp":"2026-11-22 08:30:00","event_type":"heartbeat","value":true})"
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            R"({"event_type":"heartbeat","value":true})"
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            "not-json"
        );

        std::cout
            << "[TEST] Sensor event parser: OK\n";

        return 0;
    }
    catch (const std::exception& error)
    {
        std::cerr
            << "[TEST] Sensor event parser failed: "
            << error.what()
            << '\n';

        return 1;
    }
}
