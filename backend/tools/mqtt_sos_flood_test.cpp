// Real MQTT + PostgreSQL alarm path test. No ESP32, Firebase, or user data.
#include "../src/mqtt/MqttClient.h"
#include "../src/database/Database.h"
#include "../src/alarms/AlarmRepository.h"
#include "../src/push/PushNotificationService.h"

#include <pqxx/pqxx>

#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <optional>
#include <stdexcept>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace {
constexpr const char* HOME = "home_alarm_ci";
constexpr const char* SOS = "sos_ci";
constexpr const char* FLOOD = "flood_ci";
std::atomic<int> push_attempts{0};

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

std::string getenv_required(const char* key) {
    const char* value = std::getenv(key);
    if (!value || !*value) throw std::runtime_error(std::string("Missing: ") + key);
    return value;
}

std::string quote(const std::string& value) {
    std::string result = "'";
    for (const char ch : value) {
        if (ch == '\'' || ch == '\\') result += '\\';
        result += ch;
    }
    return result + "'";
}

std::string test_conninfo() {
    const std::string host = getenv_required("VEDASENTIO_DB_HOST");
    const std::string name = getenv_required("VEDASENTIO_DB_NAME");
    // Protect real databases even if this test is launched accidentally.
    require(host == "127.0.0.1" && name == "vedasentio_alarm_ci",
            "Refusing to run on any non-test database.");
    return "host=" + quote(host) +
           " port=" + quote(getenv_required("VEDASENTIO_DB_PORT")) +
           " dbname=" + quote(name) +
           " user=" + quote(getenv_required("VEDASENTIO_DB_USER")) +
           " password=" + quote(getenv_required("VEDASENTIO_DB_PASSWORD"));
}

struct Fixture {
    explicit Fixture(std::string connection_string)
        : conninfo(std::move(connection_string)) {
        pqxx::connection connection(conninfo);
        pqxx::work tx(connection);
        tx.exec("INSERT INTO homes(id,name) VALUES($1,'Alarm MQTT CI')",
                pqxx::params{HOME});
        tx.exec("INSERT INTO devices(home_id,id,device_type,name) "
                "VALUES($1,$2,'sos_button','SOS CI')", pqxx::params{HOME,SOS});
        tx.exec("INSERT INTO devices(home_id,id,device_type,name) "
                "VALUES($1,$2,'flood_sensor','Flood CI')", pqxx::params{HOME,FLOOD});
        tx.commit();
    }

    ~Fixture() noexcept {
        try {
            pqxx::connection connection(conninfo);
            pqxx::work tx(connection);
            tx.exec("DELETE FROM alarms WHERE home_id=$1", pqxx::params{HOME});
            tx.exec("DELETE FROM sensor_events WHERE home_id=$1", pqxx::params{HOME});
            tx.exec("DELETE FROM devices WHERE home_id=$1", pqxx::params{HOME});
            tx.exec("DELETE FROM homes WHERE id=$1", pqxx::params{HOME});
            tx.commit();
        } catch (const std::exception& e) {
            std::cerr << "[ALARM-MQTT] Cleanup failed: " << e.what() << '\n';
        }
    }

    std::string conninfo;
};

template<typename Pred>
void wait_until(Pred pred, const char* error, int seconds = 25) {
    const auto deadline = std::chrono::steady_clock::now() +
        std::chrono::seconds(seconds);
    while (std::chrono::steady_clock::now() < deadline) {
        if (pred()) return;
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }
    require(pred(), error);
}

std::optional<Alarm> find_alarm(
    const AlarmRepository& repo,
    const std::string& type,
    bool active_only
) {
    for (const Alarm& alarm : repo.get_alarms(HOME, active_only, 20)) {
        if (alarm.alarm_type == type) return alarm;
    }
    return std::nullopt;
}
}

// Test-specific push implementation. It simulates Firebase being unavailable.
// The production MqttClient must preserve the alarm even when push throws.
PushNotificationService::PushNotificationService(std::string conninfo, std::string)
    : database_connection_string_(std::move(conninfo)) {}

void PushNotificationService::send_alarm_notification(const Alarm&) {
    ++push_attempts;
    throw std::runtime_error("Simulated push outage (test only)");
}

int main() {
    std::cout << std::unitbuf;
    try {
        const std::string conninfo = test_conninfo();
        Fixture fixture(conninfo);
        Database database(conninfo);
        AlarmRepository alarms(conninfo);
        PushNotificationService push(conninfo, "");
        MqttClient client(
            "tcp://127.0.0.1:" + getenv_required("VEDASENTIO_SMOKE_PORT"),
            "vedasentio_sos_flood_ci",
            "vedasentio/+/+/event",
            1, database, alarms, &push);
        client.start("ci", "ci");
        std::cout << "[ALARM-MQTT] READY\n";

        wait_until([&] {
            auto active = alarms.get_alarms(HOME, true, 10);
            return database.get_events(HOME).size() == 1 &&
                   active.size() == 1 && active[0].alarm_type == "sos";
        }, "SOS was not saved and opened");
        auto first_sos = find_alarm(alarms, "sos", true);
        require(first_sos.has_value() && first_sos->severity == "critical" &&
                first_sos->status == "active" && first_sos->source_event_id.has_value(),
                "SOS alarm metadata incorrect");
        const long long sos_alarm_id = first_sos->id;
        std::cout << "[ALARM-MQTT] SOS_OPENED\n";

        wait_until([&] {
            return database.get_events(HOME).size() == 2;
        }, "Repeated SOS event was not saved");
        auto repeated_sos = find_alarm(alarms, "sos", true);
        require(repeated_sos.has_value() && repeated_sos->id == sos_alarm_id,
                "Repeated SOS opened a duplicate active alarm");
        require(repeated_sos->last_event_id.has_value() &&
                repeated_sos->last_event_id != repeated_sos->source_event_id,
                "Repeated SOS did not update last_event_id");
        require(alarms.get_alarms(HOME, true, 10).size() == 1,
                "Repeated SOS created multiple active alarms");
        std::cout << "[ALARM-MQTT] SOS_REPEAT_OK\n";

        wait_until([&] {
            return database.get_events(HOME).size() == 3 &&
                   alarms.get_alarms(HOME, true, 10).empty();
        }, "SOS was not resolved");
        auto resolved_sos = find_alarm(alarms, "sos", false);
        require(resolved_sos.has_value() &&
                resolved_sos->id == sos_alarm_id &&
                resolved_sos->status == "resolved" &&
                resolved_sos->resolution_source == "sensor",
                "Resolved SOS not retained in history");
        std::cout << "[ALARM-MQTT] SOS_RESOLVED\n";

        // The script now sends two rejected messages; neither may write data.
        std::this_thread::sleep_for(std::chrono::seconds(2));
        require(database.get_events(HOME).size() == 3 &&
                alarms.get_alarms(HOME, true, 10).empty() &&
                push_attempts.load() == 1,
                "Rejected messages changed events, alarms, or push");
        std::cout << "[ALARM-MQTT] INVALID_REJECTED\n";

        wait_until([&] {
            auto active = find_alarm(alarms, "flood", true);
            return database.get_events(HOME).size() == 4 && active.has_value();
        }, "Flood did not open an alarm");
        auto first_flood = find_alarm(alarms, "flood", true);
        require(first_flood.has_value() &&
                first_flood->severity == "warning" &&
                first_flood->status == "active",
                "Flood severity or status incorrect");
        const long long flood_alarm_id = first_flood->id;
        std::cout << "[ALARM-MQTT] FLOOD_OPENED\n";

        wait_until([&] {
            return database.get_events(HOME).size() == 5;
        }, "Repeated flood event was not saved");
        auto repeated_flood = find_alarm(alarms, "flood", true);
        require(repeated_flood.has_value() &&
                repeated_flood->id == flood_alarm_id &&
                alarms.get_alarms(HOME, true, 10).size() == 1,
                "Repeated flood created another active alarm");
        std::cout << "[ALARM-MQTT] FLOOD_REPEAT_OK\n";

        wait_until([&] {
            return database.get_events(HOME).size() == 6 &&
                   alarms.get_alarms(HOME, true, 10).empty();
        }, "Flood alarm was not resolved");
        auto resolved_flood = find_alarm(alarms, "flood", false);
        require(resolved_flood.has_value() &&
                resolved_flood->id == flood_alarm_id &&
                resolved_flood->status == "resolved" &&
                resolved_flood->resolution_source == "sensor",
                "Flood resolution absent from alarm history");
        const auto latest_flood = database.get_latest_event(HOME, FLOOD);
        require(latest_flood.has_value() &&
                latest_flood->event_type == "flood_cleared",
                "Latest flood event is not flood_cleared");
        require(alarms.get_alarms(HOME, false, 20).size() == 2,
                "Unexpected alarm history size");
        require(push_attempts.load() == 2,
                "Push was not attempted exactly once per newly opened alarm");
        std::cout << "[ALARM-MQTT] PASS: SOS/flood open, repeat, resolve; push outage safe.\n";
        return 0;
    }
    catch (const std::exception& error) {
        std::cerr << "[ALARM-MQTT] FAILED: " << error.what() << '\n';
        return 1;
    }
}
