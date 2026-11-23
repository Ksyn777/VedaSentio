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

        const SensorEvent leap_day =
            parse_sensor_event(
                "vedasentio/home_001/door_001/event",
                "{\"timestamp\":\"2028-02-29T08:30:00Z\","
                "\"event_type\":\"heartbeat\",\"value\":true}"
            );

        require(
            leap_day.device_timestamp == "2028-02-29T08:30:00Z",
            "Valid leap day should be accepted."
        );

        expect_rejected(
            "wrong/home_001/door_001/event",
            make_payload("heartbeat", true)
        );

        expect_rejected(
            "vedasentio/home_001/door_001/event/",
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
            "{\"timestamp\":\"2026-02-30T08:30:00Z\","
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

        // Boundary checks for both identifiers, JSON shape and transport limits.
        const std::string valid_payload = make_payload("heartbeat", true);
        for (const std::string& invalid_topic : {
                 std::string("/vedasentio/home/device/event"),
                 std::string("vedasentio//device/event"),
                 std::string("vedasentio/home//event"),
                 std::string("vedasentio/home/device/other"),
                 std::string("vedasentio/home/device/event/extra"),
                 std::string("vedasentio/home/dev+ice/event"),
                 std::string("vedasentio/home/dev#ice/event"),
                 "vedasentio/" + std::string(65, 'h') + "/device/event",
                 "vedasentio/home/" + std::string(65, 'd') + "/event"})
        {
            expect_rejected(invalid_topic, valid_payload);
        }

        const auto boundary_ids = parse_sensor_event(
            "vedasentio/" + std::string(64, 'h') + "/" +
                std::string(64, 'd') + "/event", valid_payload);
        require(boundary_ids.home_id.size() == 64 &&
                    boundary_ids.device_id.size() == 64,
                "64-character identifiers should be accepted.");
        (void)parse_sensor_event("vedasentio/home-001/device_001/event", valid_payload);

        const std::string topic = "vedasentio/home/device/event";
        for (const std::string& invalid_payload : {
                 std::string("[]"), std::string("null"), std::string("true"),
                 std::string("{}"),
                 std::string(R"({"timestamp":"2026-11-22T08:30:00Z","event_type":"heartbeat"})"),
                 std::string(R"({"timestamp":"2026-11-22T08:30:00Z","event_type":1,"value":true})"),
                 std::string(R"({"timestamp":1,"event_type":"heartbeat","value":true})"),
                 std::string(R"({"timestamp":"2026-11-22T08:30:00Z","event_type":"heartbeat","value":1})")})
        {
            expect_rejected(topic, invalid_payload);
        }
        for (const auto& [event_type, value] : supported_events)
        {
            expect_rejected(topic, make_payload(event_type, !value));
        }
        for (const char* invalid_time : {
                 "2026-02-29T08:30:00Z", "2026-13-01T08:30:00Z",
                 "2026-11-22T24:00:00Z", "2026-11-22T08:60:00Z",
                 "2026-11-22T08:30:60Z", "2026-11-22T08:30:00.Z",
                 "2026-11-22T08:30:00+01:00"})
        {
            expect_rejected(topic, std::string("{\"timestamp\":\"") + invalid_time +
                "\",\"event_type\":\"heartbeat\",\"value\":true}");
        }
        std::string limit_payload = valid_payload;
        limit_payload.append(4096 - limit_payload.size(), ' ');
        (void)parse_sensor_event(topic, limit_payload);
        expect_rejected(topic, limit_payload + " ");

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
