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

            tx.commit();
        }

        Database database(conninfo);
        AlarmRepository alarms(conninfo);

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
