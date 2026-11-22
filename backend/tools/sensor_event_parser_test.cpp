#include "../src/mqtt/SensorEventParser.h"

#include <array>
#include <iostream>
#include <stdexcept>
#include <string>
#include <utility>

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

std::string make_payload(
    const std::string& event_type,
    bool value
)
{
    return
        "{\"timestamp\":\"2026-11-22T08:30:00Z\","
        "\"event_type\":\"" +
        event_type +
        "\",\"value\":" +
        (value ? "true" : "false") +
        "}";
}
}

int main()
{
    try
    {
        const std::array<std::pair<std::string, bool>, 13>
            supported_events = {{
                {"heartbeat", true},
                {"door_opened", true},
                {"door_closed", false},
                {"sos_pressed", true},
                {"sos_resolved", false},
                {"smoke_detected", true},
                {"smoke_cleared", false},
                {"co_detected", true},
                {"co_cleared", false},
                {"gas_detected", true},
                {"gas_cleared", false},
                {"flood_detected", true},
                {"flood_cleared", false}
            }};

        for (const auto& [event_type, value] : supported_events)
        {
            const SensorEvent event =
                parse_sensor_event(
                    "vedasentio/home_001/door_001/event",
                    make_payload(
                        event_type,
                        value
                    )
                );

            require(
                event.event_type == event_type,
                "Supported event_type parsing failed."
            );
        }

        const SensorEvent timestamp_with_milliseconds =
            parse_sensor_event(
                "vedasentio/home_001/door_001/event",
                "{\"timestamp\":\"2026-11-22T08:30:00.125Z\","
                "\"event_type\":\"door_closed\",\"value\":false}"
            );

        require(
            timestamp_with_milliseconds.value_json == "false",
            "Timestamp with milliseconds should be accepted."
        );

        expect_rejected(
            "wrong/home_001/door_001/event",
            make_payload("heartbeat", true)
        );

        expect_rejected(
            "vedasentio/home 001/door_001/event",
            make_payload("heartbeat", true)
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            "{\"timestamp\":\"2026-11-22T08:30:00Z\","
            "\"event_type\":\"unknown_event\",\"value\":true}"
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            make_payload("door_opened", false)
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            "{\"timestamp\":\"2026-11-22T08:30:00Z\","
            "\"event_type\":\"door_closed\",\"value\":\"false\"}"
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            "{\"timestamp\":\"2026-11-22 08:30:00\","
            "\"event_type\":\"heartbeat\",\"value\":true}"
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event",
            "{\"event_type\":\"heartbeat\",\"value\":true}"
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
