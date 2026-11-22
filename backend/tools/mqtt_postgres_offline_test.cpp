#include "../src/mqtt/MqttClient.h"
#include "../src/database/Database.h"
#include "../src/alarms/AlarmRepository.h"
#include "../src/push/PushNotificationService.h"

#include <pqxx/pqxx>

#include <chrono>
#include <cstdlib>
#include <exception>
#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace {
constexpr const char* HOME = "home_ci";
constexpr const char* DEVICE = "door_ci";
constexpr const char* INACTIVE = "inactive_ci";

std::string required(const char* name) {
    const char* value = std::getenv(name);
    if (!value || !*value) {
        throw std::runtime_error(std::string("Missing test variable: ") + name);
    }
    return value;
}

std::string quoted(const std::string& input) {
    std::string escaped = "'";
    for (char c : input) {
        if (c == '\\' || c == '\'') escaped += '\\';
        escaped += c;
    }
    return escaped + "'";
}

std::string connection_string() {
    const std::string host = required("VEDASENTIO_DB_HOST");
    const std::string port = required("VEDASENTIO_DB_PORT");
    const std::string name = required("VEDASENTIO_DB_NAME");

    // Hard gate: never run this destructive fixture against an ordinary DB.
    if (host != "127.0.0.1" || name != "vedasentio_mqtt_ci") {
        throw std::runtime_error("Refusing non-local or non-test database.");
    }

    return "host=" + quoted(host) +
           " port=" + quoted(port) +
           " dbname=" + quoted(name) +
           " user=" + quoted(required("VEDASENTIO_DB_USER")) +
           " password=" + quoted(required("VEDASENTIO_DB_PASSWORD"));
}

struct DisposableFixture {
    explicit DisposableFixture(std::string s) : conninfo(std::move(s)) {
        pqxx::connection db(conninfo);
        pqxx::work tx(db);
        tx.exec("INSERT INTO homes(id,name) VALUES($1,'MQTT CI home')",
                pqxx::params{HOME});
        tx.exec("INSERT INTO devices(home_id,id,device_type,name) "
                "VALUES($1,$2,'door_contact','MQTT CI door')",
                pqxx::params{HOME, DEVICE});
        tx.exec("INSERT INTO devices(home_id,id,device_type,name,is_active) "
                "VALUES($1,$2,'door_contact','Inactive CI device',FALSE)",
                pqxx::params{HOME, INACTIVE});
        tx.commit();
    }

    ~DisposableFixture() noexcept {
        try {
            pqxx::connection db(conninfo);
            pqxx::work tx(db);
            tx.exec("DELETE FROM homes WHERE id=$1", pqxx::params{HOME});
            tx.commit();
        } catch (const std::exception& e) {
            std::cerr << "[PG] Fixture cleanup failed: " << e.what() << '\n';
        }
    }

    std::string conninfo;
};

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

template <typename Condition>
bool wait_until(Condition condition, std::chrono::seconds timeout) {
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    do {
        if (condition()) return true;
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    } while (std::chrono::steady_clock::now() < deadline);
    return condition();
}

std::vector<Device> device_list(Database& db) {
    std::vector<Device> selected;
    for (const auto& device : db.get_devices(HOME)) {
        if (device.id == DEVICE) selected.push_back(device);
    }
    return selected;
}

bool inactive_device_unmodified(Database& db) {
    for (const auto& device : db.get_devices(HOME)) {
        if (device.id == INACTIVE) {
            return !device.is_active && device.last_seen_at.empty();
        }
    }
    return false;
}

void force_device_offline(const std::string& conninfo) {
    pqxx::connection db(conninfo);
    pqxx::work tx(db);
    tx.exec("UPDATE devices SET last_seen_at = NOW() - INTERVAL '3 minutes' "
            "WHERE home_id=$1 AND id=$2", pqxx::params{HOME, DEVICE});
    tx.commit();
}
}

// The optional push pointer passed to MqttClient is null. This link-time
// stub cannot send notifications or reach Firebase.
void PushNotificationService::send_alarm_notification(const Alarm&) {}

int main() {
    std::cout << std::unitbuf;
    try {
        const std::string conninfo = connection_string();
        DisposableFixture fixture(conninfo);
        Database db(conninfo);
        AlarmRepository alarms(conninfo);
        db.test_connection();

        MqttClient listener(
            "tcp://127.0.0.1:" + required("VEDASENTIO_SMOKE_PORT"),
            "vedasentio_pg_ci_subscriber",
            "vedasentio/+/+/event", 1, db, alarms, nullptr);

        listener.start("ci_smoke", "ci_smoke");
        std::cout << "[PG] INITIAL_SUBSCRIBED\n";

        // Heartbeats update last_seen but do not create sensor_event rows.
        require(wait_until([&] {
            auto d = device_list(db);
            return d.size() == 1 && d[0].is_online;
        }, std::chrono::seconds(25)), "Initial heartbeat did not make device online.");
        require(db.get_events(HOME).empty(), "Heartbeat created a sensor event.");
        auto original = device_list(db)[0].last_seen_at;
        std::cout << "[PG] INITIAL_HEARTBEAT_OK\n";

        // The script sends malformed JSON value here. No DB mutation allowed.
        std::this_thread::sleep_for(std::chrono::seconds(2));
        require(db.get_events(HOME).empty(), "Invalid payload was saved.");
        require(device_list(db)[0].last_seen_at == original,
                "Invalid payload changed device last_seen.");
        require(inactive_device_unmodified(db),
                "Rejected event modified an inactive device.");
        require(alarms.get_alarms(HOME, true, 10).empty(),
                "Rejected event created an alarm.");

        // Simulate a device that did not report for 3 minutes.
        force_device_offline(conninfo);
        auto offline = device_list(db);
        require(offline.size() == 1 && !offline[0].is_online,
                "Stale heartbeat was not recognized as offline.");

        auto new_alarm = alarms.open_device_offline_alarm(HOME, DEVICE);
        require(new_alarm.has_value(), "Offline alarm was not opened.");
        require(new_alarm->alarm_type == "device_offline",
                "Wrong offline alarm type.");
        for (int attempt = 0; attempt < 3; ++attempt) {
            require(!alarms.open_device_offline_alarm(HOME, DEVICE).has_value(),
                    "Repeated offline check created a duplicate alarm.");
        }
        auto active = alarms.get_alarms(HOME, true, 10);
        require(active.size() == 1 && active[0].id == new_alarm->id,
                "Expected exactly one active offline alarm.");
        std::cout << "[PG] OFFLINE_ALARM_OPENED\n";

        // Script stops broker, restarts it, then publishes another heartbeat.
        require(wait_until([&] {
            auto d = device_list(db);
            auto alarms_now = alarms.get_alarms(HOME, true, 10);
            return d.size() == 1 && d[0].is_online && alarms_now.empty();
        }, std::chrono::seconds(75)),
        "Heartbeat after reconnect did not resolve offline alarm.");

        auto history = alarms.get_alarms(HOME, false, 10);
        require(history.size() == 1 &&
                history[0].id == new_alarm->id &&
                history[0].status == "resolved",
                "Offline alarm was not resolved exactly once.");
        require(db.get_events(HOME).empty(),
                "Heartbeat after reconnect created a sensor event.");
        std::cout << "[PG] HEARTBEAT_RESOLVED_OFFLINE\n";

        // Script publishes one door event, then checks for duplicates.
        require(wait_until([&] {
            return db.get_events(HOME).size() >= 1;
        }, std::chrono::seconds(25)), "Door event was not saved after reconnect.");

        std::this_thread::sleep_for(std::chrono::seconds(2));
        auto events = db.get_events(HOME);
        require(events.size() == 1 && events[0].event_type == "door_opened",
                "Wrong or duplicate sensor events after reconnect.");
        require(alarms.get_alarms(HOME, true, 10).empty(),
                "Reconnect unexpectedly created an active alarm.");
        std::cout << "[PG] PASS: DB events, one offline alarm, heartbeat resolution.\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "[PG] FAILED: " << e.what() << '\n';
        return 1;
    }
}
