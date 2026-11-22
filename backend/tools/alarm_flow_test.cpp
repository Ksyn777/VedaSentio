#include "../src/alarms/AlarmRepository.h"
#include "../src/database/Database.h"
#include "../src/model/SensorEvent.h"

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>

#include <pqxx/pqxx>

namespace
{
std::string require_env(const char* name)
{
    const char* value = std::getenv(name);

    if (value == nullptr || *value == '\0')
        throw std::runtime_error(
            std::string("Missing environment variable: ") + name
        );

    return value;
}

std::string quote_conninfo_value(const std::string& value)
{
    std::string result = "'";

    for (char character : value)
    {
        if (character == '\\' || character == '\'')
            result.push_back('\\');
        result.push_back(character);
    }

    result.push_back('\'');
    return result;
}

std::string build_conninfo()
{
    return
        "host=" + quote_conninfo_value(require_env("VEDASENTIO_DB_HOST")) +
        " port=" + quote_conninfo_value(require_env("VEDASENTIO_DB_PORT")) +
        " dbname=" + quote_conninfo_value(require_env("VEDASENTIO_DB_NAME")) +
        " user=" + quote_conninfo_value(require_env("VEDASENTIO_DB_USER")) +
        " password=" + quote_conninfo_value(require_env("VEDASENTIO_DB_PASSWORD"));
}

void cleanup(
    const std::string& conninfo,
    const std::string& home_id
)
{
    pqxx::connection connection(conninfo);
    pqxx::work tx(connection);

    tx.exec("DELETE FROM alarms WHERE home_id = $1", pqxx::params{home_id});
    tx.exec("DELETE FROM sensor_events WHERE home_id = $1", pqxx::params{home_id});
    tx.exec("DELETE FROM devices WHERE home_id = $1", pqxx::params{home_id});
    tx.exec("DELETE FROM homes WHERE id = $1", pqxx::params{home_id});
    tx.commit();
}
}

int main()
{
    const std::string conninfo = build_conninfo();

    const auto stamp =
        std::chrono::system_clock::now()
            .time_since_epoch()
            .count();

    const std::string home_id =
        "alarm_test_" + std::to_string(stamp);

    const std::string sos_device_id = "sos_test";
    const std::string gas_device_id = "gas_test";
    const std::string co_device_id = "co_test";
    const std::string smoke_device_id = "smoke_test";
    const std::string flood_device_id = "flood_test";
    const std::string door_device_id = "door_test";

    try
    {
        {
            pqxx::connection connection(conninfo);
            pqxx::work tx(connection);

            tx.exec(
                "INSERT INTO homes(id, name) VALUES($1, $2)",
                pqxx::params{home_id, "Alarm flow test"}
            );

            tx.exec(
                "INSERT INTO devices(home_id, id, device_type, name) "
                "VALUES($1, $2, 'sos_button', 'SOS test')",
                pqxx::params{home_id, sos_device_id}
            );

            tx.exec(
                "INSERT INTO devices(home_id, id, device_type, name) "
                "VALUES($1, $2, 'gas_sensor', 'Gas test')",
                pqxx::params{home_id, gas_device_id}
            );

            tx.exec(
                "INSERT INTO devices(home_id, id, device_type, name) "
                "VALUES($1, $2, 'co_sensor', 'CO test')",
                pqxx::params{home_id, co_device_id}
            );

            tx.exec(
                "INSERT INTO devices(home_id, id, device_type, name) "
                "VALUES($1, $2, 'smoke_sensor', 'Smoke test')",
                pqxx::params{home_id, smoke_device_id}
            );

            tx.exec(
                "INSERT INTO devices(home_id, id, device_type, name) "
                "VALUES($1, $2, 'flood_sensor', 'Flood test')",
                pqxx::params{home_id, flood_device_id}
            );

            tx.exec(
                "INSERT INTO devices(home_id, id, device_type, name) "
                "VALUES($1, $2, 'door_contact', 'Door contact test')",
                pqxx::params{home_id, door_device_id}
            );

            tx.commit();
        }

        Database database(conninfo);
        AlarmRepository alarms(conninfo);

        SensorEvent heartbeat;
        heartbeat.topic = "vedasentio/" + home_id + "/" + door_device_id + "/event";
        heartbeat.home_id = home_id;
        heartbeat.device_id = door_device_id;
        heartbeat.event_type = "heartbeat";
        heartbeat.value_json = "true";
        heartbeat.device_timestamp = "2026-10-05T15:59:00Z";
        heartbeat.raw_payload = "{\"event_type\":\"heartbeat\",\"value\":true,\"timestamp\":\"2026-10-05T15:59:00Z\"}";

        const auto heartbeat_alarm =
            alarms.process_event(
                heartbeat,
                0
            );

        if (heartbeat_alarm.has_value() ||
            !alarms.get_alarms(home_id, true, 10).empty())
        {
            throw std::runtime_error("Heartbeat unexpectedly created an alarm.");
        }

        std::cout << "[ALARM-TEST] Heartbeat did not create an alarm.\n";

        SensorEvent inactive_flood;
        inactive_flood.topic = "vedasentio/" + home_id + "/" + flood_device_id + "/event";
        inactive_flood.home_id = home_id;
        inactive_flood.device_id = flood_device_id;
        inactive_flood.event_type = "flood_detected";
        inactive_flood.value_json = "false";
        inactive_flood.device_timestamp = "2026-10-05T15:59:30Z";
        inactive_flood.raw_payload = "{\"event_type\":\"flood_detected\",\"value\":false,\"timestamp\":\"2026-10-05T15:59:30Z\"}";

        const auto inactive_flood_alarm =
            alarms.process_event(
                inactive_flood,
                0
            );

        if (inactive_flood_alarm.has_value() ||
            !alarms.get_alarms(home_id, true, 10).empty())
        {
            throw std::runtime_error("Inactive flood value unexpectedly created an alarm.");
        }

        std::cout << "[ALARM-TEST] Inactive alarm value was ignored.\n";

        SensorEvent pressed;
        pressed.topic = "vedasentio/" + home_id + "/" + sos_device_id + "/event";
        pressed.home_id = home_id;
        pressed.device_id = sos_device_id;
        pressed.event_type = "sos_pressed";
        pressed.value_json = "true";
        pressed.device_timestamp = "2026-10-05T16:00:00Z";
        pressed.raw_payload = "{\"event_type\":\"sos_pressed\",\"value\":true,\"timestamp\":\"2026-10-05T16:00:00Z\"}";

        const long long press_id = database.save_event(pressed);
        alarms.process_event(pressed, press_id);

        const auto active_sos = alarms.get_alarms(home_id, true, 10);

        if (active_sos.size() != 1 ||
            active_sos[0].alarm_type != "sos" ||
            active_sos[0].severity != "critical" ||
            active_sos[0].status != "active")
        {
            throw std::runtime_error("SOS alarm was not opened correctly.");
        }

        std::cout << "[ALARM-TEST] SOS opened OK.\n";

        SensorEvent resolved = pressed;
        resolved.event_type = "sos_resolved";
        resolved.value_json = "false";
        resolved.device_timestamp = "2026-10-05T16:01:00Z";
        resolved.raw_payload = "{\"event_type\":\"sos_resolved\",\"value\":false,\"timestamp\":\"2026-10-05T16:01:00Z\"}";

        const long long resolve_id = database.save_event(resolved);
        alarms.process_event(resolved, resolve_id);

        if (!alarms.get_alarms(home_id, true, 10).empty())
            throw std::runtime_error("SOS alarm remained active after resolution.");

        const auto sos_history = alarms.get_alarms(home_id, false, 10);

        if (sos_history.size() != 1 || sos_history[0].status != "resolved")
            throw std::runtime_error("Resolved SOS alarm was not preserved in history.");

        std::cout << "[ALARM-TEST] SOS resolved OK.\n";
        std::cout << "[ALARM-TEST] Alarm history preserved OK.\n";

        SensorEvent gas_detected;
        gas_detected.topic = "vedasentio/" + home_id + "/" + gas_device_id + "/event";
        gas_detected.home_id = home_id;
        gas_detected.device_id = gas_device_id;
        gas_detected.event_type = "gas_detected";
        gas_detected.value_json = "true";
        gas_detected.device_timestamp = "2026-10-05T16:02:00Z";
        gas_detected.raw_payload = "{\"event_type\":\"gas_detected\",\"value\":true,\"timestamp\":\"2026-10-05T16:02:00Z\"}";

        const long long gas_detected_id = database.save_event(gas_detected);
        alarms.process_event(gas_detected, gas_detected_id);

        const auto active_gas = alarms.get_alarms(home_id, true, 10);

        if (active_gas.size() != 1 ||
            active_gas[0].alarm_type != "gas" ||
            active_gas[0].severity != "critical" ||
            active_gas[0].status != "active")
        {
            throw std::runtime_error("Gas alarm was not opened correctly.");
        }

        const long long first_gas_alarm_id = active_gas[0].id;

        std::cout << "[ALARM-TEST] Gas alarm opened OK.\n";

        SensorEvent gas_detected_again = gas_detected;
        gas_detected_again.device_timestamp = "2026-10-05T16:02:10Z";
        gas_detected_again.raw_payload = "{\"event_type\":\"gas_detected\",\"value\":true,\"timestamp\":\"2026-10-05T16:02:10Z\"}";

        const long long gas_detected_again_id = database.save_event(gas_detected_again);
        alarms.process_event(gas_detected_again, gas_detected_again_id);

        const auto active_gas_after_repeat = alarms.get_alarms(home_id, true, 10);

        if (active_gas_after_repeat.size() != 1 ||
            active_gas_after_repeat[0].id != first_gas_alarm_id)
        {
            throw std::runtime_error("Repeated gas event created a duplicate alarm.");
        }

        std::cout << "[ALARM-TEST] Repeated gas event did not create duplicate alarm.\n";

        SensorEvent gas_cleared = gas_detected;
        gas_cleared.event_type = "gas_cleared";
        gas_cleared.value_json = "false";
        gas_cleared.device_timestamp = "2026-10-05T16:03:00Z";
        gas_cleared.raw_payload = "{\"event_type\":\"gas_cleared\",\"value\":false,\"timestamp\":\"2026-10-05T16:03:00Z\"}";

        const long long gas_cleared_id = database.save_event(gas_cleared);
        alarms.process_event(gas_cleared, gas_cleared_id);

        if (!alarms.get_alarms(home_id, true, 10).empty())
            throw std::runtime_error("Gas alarm remained active after gas_cleared.");

        const auto full_history = alarms.get_alarms(home_id, false, 10);

        bool resolved_gas_alarm_found = false;

        for (const Alarm& alarm : full_history)
        {
            if (alarm.alarm_type == "gas" && alarm.status == "resolved")
            {
                resolved_gas_alarm_found = true;
            }
        }

        if (!resolved_gas_alarm_found)
            throw std::runtime_error("Resolved gas alarm was not preserved in history.");

        std::cout << "[ALARM-TEST] Gas alarm resolved OK.\n";
        std::cout << "[ALARM-TEST] Gas alarm history preserved OK.\n";

        SensorEvent co_detected;
        co_detected.topic = "vedasentio/" + home_id + "/" + co_device_id + "/event";
        co_detected.home_id = home_id;
        co_detected.device_id = co_device_id;
        co_detected.event_type = "co_detected";
        co_detected.value_json = "true";
        co_detected.device_timestamp = "2026-10-05T16:04:00Z";
        co_detected.raw_payload = "{\"event_type\":\"co_detected\",\"value\":true,\"timestamp\":\"2026-10-05T16:04:00Z\"}";

        const long long co_detected_id = database.save_event(co_detected);
        alarms.process_event(co_detected, co_detected_id);

        const auto active_co = alarms.get_alarms(home_id, true, 10);

        if (active_co.size() != 1 ||
            active_co[0].alarm_type != "co" ||
            active_co[0].severity != "critical" ||
            active_co[0].status != "active")
        {
            throw std::runtime_error("CO alarm was not opened correctly.");
        }

        const long long first_co_alarm_id = active_co[0].id;

        std::cout << "[ALARM-TEST] CO alarm opened OK.\n";

        SensorEvent co_detected_again = co_detected;
        co_detected_again.device_timestamp = "2026-10-05T16:04:10Z";
        co_detected_again.raw_payload = "{\"event_type\":\"co_detected\",\"value\":true,\"timestamp\":\"2026-10-05T16:04:10Z\"}";

        const long long co_detected_again_id = database.save_event(co_detected_again);
        alarms.process_event(co_detected_again, co_detected_again_id);

        const auto active_co_after_repeat = alarms.get_alarms(home_id, true, 10);

        if (active_co_after_repeat.size() != 1 ||
            active_co_after_repeat[0].id != first_co_alarm_id)
        {
            throw std::runtime_error("Repeated CO event created a duplicate alarm.");
        }

        std::cout << "[ALARM-TEST] Repeated CO event did not create duplicate alarm.\n";

        SensorEvent co_cleared = co_detected;
        co_cleared.event_type = "co_cleared";
        co_cleared.value_json = "false";
        co_cleared.device_timestamp = "2026-10-05T16:05:00Z";
        co_cleared.raw_payload = "{\"event_type\":\"co_cleared\",\"value\":false,\"timestamp\":\"2026-10-05T16:05:00Z\"}";

        const long long co_cleared_id = database.save_event(co_cleared);
        alarms.process_event(co_cleared, co_cleared_id);

        if (!alarms.get_alarms(home_id, true, 10).empty())
            throw std::runtime_error("CO alarm remained active after co_cleared.");

        const auto history_after_co = alarms.get_alarms(home_id, false, 10);

        bool resolved_co_alarm_found = false;

        for (const Alarm& alarm : history_after_co)
        {
            if (alarm.alarm_type == "co" && alarm.status == "resolved")
            {
                resolved_co_alarm_found = true;
            }
        }

        if (!resolved_co_alarm_found)
            throw std::runtime_error("Resolved CO alarm was not preserved in history.");

        std::cout << "[ALARM-TEST] CO alarm resolved OK.\n";
        std::cout << "[ALARM-TEST] CO alarm history preserved OK.\n";

        SensorEvent smoke_detected;
        smoke_detected.topic = "vedasentio/" + home_id + "/" + smoke_device_id + "/event";
        smoke_detected.home_id = home_id;
        smoke_detected.device_id = smoke_device_id;
        smoke_detected.event_type = "smoke_detected";
        smoke_detected.value_json = "true";
        smoke_detected.device_timestamp = "2026-10-05T16:06:00Z";
        smoke_detected.raw_payload = "{\"event_type\":\"smoke_detected\",\"value\":true,\"timestamp\":\"2026-10-05T16:06:00Z\"}";

        const long long smoke_detected_id = database.save_event(smoke_detected);
        alarms.process_event(smoke_detected, smoke_detected_id);

        const auto active_smoke = alarms.get_alarms(home_id, true, 10);

        if (active_smoke.size() != 1 ||
            active_smoke[0].alarm_type != "smoke" ||
            active_smoke[0].severity != "critical" ||
            active_smoke[0].status != "active")
        {
            throw std::runtime_error("Smoke alarm was not opened correctly.");
        }

        const long long first_smoke_alarm_id = active_smoke[0].id;
        std::cout << "[ALARM-TEST] Smoke alarm opened OK.\n";

        SensorEvent smoke_detected_again = smoke_detected;
        smoke_detected_again.device_timestamp = "2026-10-05T16:06:10Z";
        smoke_detected_again.raw_payload = "{\"event_type\":\"smoke_detected\",\"value\":true,\"timestamp\":\"2026-10-05T16:06:10Z\"}";

        const long long smoke_detected_again_id = database.save_event(smoke_detected_again);
        alarms.process_event(smoke_detected_again, smoke_detected_again_id);

        const auto active_smoke_after_repeat = alarms.get_alarms(home_id, true, 10);

        if (active_smoke_after_repeat.size() != 1 ||
            active_smoke_after_repeat[0].id != first_smoke_alarm_id)
        {
            throw std::runtime_error("Repeated smoke event created a duplicate alarm.");
        }

        std::cout << "[ALARM-TEST] Repeated smoke event did not create duplicate alarm.\n";

        SensorEvent smoke_cleared = smoke_detected;
        smoke_cleared.event_type = "smoke_cleared";
        smoke_cleared.value_json = "false";
        smoke_cleared.device_timestamp = "2026-10-05T16:07:00Z";
        smoke_cleared.raw_payload = "{\"event_type\":\"smoke_cleared\",\"value\":false,\"timestamp\":\"2026-10-05T16:07:00Z\"}";

        const long long smoke_cleared_id = database.save_event(smoke_cleared);
        alarms.process_event(smoke_cleared, smoke_cleared_id);

        if (!alarms.get_alarms(home_id, true, 10).empty())
            throw std::runtime_error("Smoke alarm remained active after smoke_cleared.");

        const auto history_after_smoke = alarms.get_alarms(home_id, false, 20);
        bool resolved_smoke_alarm_found = false;

        for (const Alarm& alarm : history_after_smoke)
        {
            if (alarm.alarm_type == "smoke" && alarm.status == "resolved")
                resolved_smoke_alarm_found = true;
        }

        if (!resolved_smoke_alarm_found)
            throw std::runtime_error("Resolved smoke alarm was not preserved in history.");

        std::cout << "[ALARM-TEST] Smoke alarm resolved OK.\n";
        std::cout << "[ALARM-TEST] Smoke alarm history preserved OK.\n";

        SensorEvent flood_detected;
        flood_detected.topic = "vedasentio/" + home_id + "/" + flood_device_id + "/event";
        flood_detected.home_id = home_id;
        flood_detected.device_id = flood_device_id;
        flood_detected.event_type = "flood_detected";
        flood_detected.value_json = "true";
        flood_detected.device_timestamp = "2026-10-05T16:08:00Z";
        flood_detected.raw_payload = "{\"event_type\":\"flood_detected\",\"value\":true,\"timestamp\":\"2026-10-05T16:08:00Z\"}";

        const long long flood_detected_id = database.save_event(flood_detected);
        alarms.process_event(flood_detected, flood_detected_id);

        const auto active_flood = alarms.get_alarms(home_id, true, 10);

        if (active_flood.size() != 1 ||
            active_flood[0].alarm_type != "flood" ||
            active_flood[0].severity != "warning" ||
            active_flood[0].status != "active")
        {
            throw std::runtime_error("Flood alarm was not opened correctly.");
        }

        const long long first_flood_alarm_id = active_flood[0].id;
        std::cout << "[ALARM-TEST] Flood alarm opened OK.\n";

        SensorEvent flood_detected_again = flood_detected;
        flood_detected_again.device_timestamp = "2026-10-05T16:08:10Z";
        flood_detected_again.raw_payload = "{\"event_type\":\"flood_detected\",\"value\":true,\"timestamp\":\"2026-10-05T16:08:10Z\"}";

        const long long flood_detected_again_id = database.save_event(flood_detected_again);
        alarms.process_event(flood_detected_again, flood_detected_again_id);

        const auto active_flood_after_repeat = alarms.get_alarms(home_id, true, 10);

        if (active_flood_after_repeat.size() != 1 ||
            active_flood_after_repeat[0].id != first_flood_alarm_id)
        {
            throw std::runtime_error("Repeated flood event created a duplicate alarm.");
        }

        std::cout << "[ALARM-TEST] Repeated flood event did not create duplicate alarm.\n";

        SensorEvent flood_cleared = flood_detected;
        flood_cleared.event_type = "flood_cleared";
        flood_cleared.value_json = "false";
        flood_cleared.device_timestamp = "2026-10-05T16:09:00Z";
        flood_cleared.raw_payload = "{\"event_type\":\"flood_cleared\",\"value\":false,\"timestamp\":\"2026-10-05T16:09:00Z\"}";

        const long long flood_cleared_id = database.save_event(flood_cleared);
        alarms.process_event(flood_cleared, flood_cleared_id);

        if (!alarms.get_alarms(home_id, true, 10).empty())
            throw std::runtime_error("Flood alarm remained active after flood_cleared.");

        const auto history_after_flood = alarms.get_alarms(home_id, false, 20);
        bool resolved_flood_alarm_found = false;

        for (const Alarm& alarm : history_after_flood)
        {
            if (alarm.alarm_type == "flood" && alarm.status == "resolved")
                resolved_flood_alarm_found = true;
        }

        if (!resolved_flood_alarm_found)
            throw std::runtime_error("Resolved flood alarm was not preserved in history.");

        std::cout << "[ALARM-TEST] Flood alarm resolved OK.\n";
        std::cout << "[ALARM-TEST] Flood alarm history preserved OK.\n";

        SensorEvent door_opened;
        door_opened.topic = "vedasentio/" + home_id + "/" + door_device_id + "/event";
        door_opened.home_id = home_id;
        door_opened.device_id = door_device_id;
        door_opened.event_type = "door_opened";
        door_opened.value_json = "true";
        door_opened.device_timestamp = "2026-10-05T16:10:00Z";
        door_opened.raw_payload = "{\"event_type\":\"door_opened\",\"value\":true,\"timestamp\":\"2026-10-05T16:10:00Z\"}";

        const long long door_opened_id = database.save_event(door_opened);
        const auto door_opened_alarm = alarms.process_event(door_opened, door_opened_id);

        if (door_opened_alarm.has_value())
            throw std::runtime_error("Door opened event unexpectedly created an alarm.");

        if (!alarms.get_alarms(home_id, true, 10).empty())
            throw std::runtime_error("Door opened event created an active alarm.");

        std::cout << "[DOOR-TEST] door_opened stored without alarm.\n";

        SensorEvent door_closed = door_opened;
        door_closed.event_type = "door_closed";
        door_closed.value_json = "false";
        door_closed.device_timestamp = "2026-10-05T16:10:30Z";
        door_closed.raw_payload = "{\"event_type\":\"door_closed\",\"value\":false,\"timestamp\":\"2026-10-05T16:10:30Z\"}";

        const long long door_closed_id = database.save_event(door_closed);
        const auto door_closed_alarm = alarms.process_event(door_closed, door_closed_id);

        if (door_closed_alarm.has_value())
            throw std::runtime_error("Door closed event unexpectedly created an alarm.");

        const auto latest_door_event = database.get_latest_event(home_id, door_device_id);

        if (!latest_door_event.has_value() ||
            latest_door_event->event_type != "door_closed")
        {
            throw std::runtime_error("Latest door state was not saved correctly.");
        }

        const auto recent_events = database.get_events(home_id, 100);

        bool door_opened_found = false;
        bool door_closed_found = false;

        for (const auto& event : recent_events)
        {
            if (event.device_id != door_device_id)
                continue;

            if (event.event_type == "door_opened")
                door_opened_found = true;

            if (event.event_type == "door_closed")
                door_closed_found = true;
        }

        if (!door_opened_found || !door_closed_found)
            throw std::runtime_error("Door contact events were not preserved in event history.");

        std::cout << "[DOOR-TEST] door_closed stored without alarm.\n";
        std::cout << "[DOOR-TEST] Door event history preserved OK.\n";
        std::cout << "[DOOR-TEST] Latest door state is door_closed.\n";
        const auto offline_alarm =
            alarms.open_device_offline_alarm(
                home_id,
                door_device_id
            );

        if (!offline_alarm.has_value() ||
            offline_alarm->alarm_type != "device_offline" ||
            offline_alarm->severity != "warning" ||
            offline_alarm->status != "active")
        {
            throw std::runtime_error("Device offline alarm was not opened correctly.");
        }

        const auto duplicate_offline_alarm =
            alarms.open_device_offline_alarm(
                home_id,
                door_device_id
            );

        if (duplicate_offline_alarm.has_value())
        {
            throw std::runtime_error("Repeated offline check created a duplicate alarm.");
        }

        const auto active_after_offline =
            alarms.get_alarms(
                home_id,
                true,
                20
            );

        int active_offline_count = 0;

        for (const Alarm& alarm : active_after_offline)
        {
            if (alarm.alarm_type == "device_offline")
                ++active_offline_count;
        }

        if (active_offline_count != 1)
        {
            throw std::runtime_error("Expected exactly one active device_offline alarm.");
        }

        if (!alarms.resolve_device_offline_alarm(home_id, door_device_id))
        {
            throw std::runtime_error("Device offline alarm was not resolved.");
        }

        const auto history_after_offline =
            alarms.get_alarms(
                home_id,
                false,
                50
            );

        bool resolved_offline_found = false;

        for (const Alarm& alarm : history_after_offline)
        {
            if (alarm.alarm_type == "device_offline" &&
                alarm.status == "resolved" &&
                alarm.resolution_source == "sensor")
            {
                resolved_offline_found = true;
            }
        }

        if (!resolved_offline_found)
        {
            throw std::runtime_error("Resolved device_offline alarm was not preserved in history.");
        }

        std::cout << "[ALARM-TEST] Device offline alarm cycle OK.\n";
        std::cout << "[ALARM-TEST] ALL ALARM FLOW TESTS OK.\n";

        cleanup(conninfo, home_id);
        return 0;
    }
    catch (const std::exception& error)
    {
        try { cleanup(conninfo, home_id); } catch (...) {}

        std::cerr << "[ALARM-TEST] Error: " << error.what() << '\n';
        return 1;
    }
}
