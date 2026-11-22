#include "../src/mqtt/MqttClient.h"
#include "../src/alarms/AlarmRepository.h"
#include "../src/database/Database.h"
#include "../src/push/PushNotificationService.h"

#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <iostream>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace {
struct SmokeState {
    std::mutex mutex;
    std::condition_variable changed;
    std::vector<std::string> saved_events;
    int last_seen_updates = 0;
    int offline_resolutions = 0;
};

SmokeState state;

bool wait_for_events(std::size_t count, std::chrono::seconds timeout) {
    std::unique_lock<std::mutex> lock(state.mutex);
    return state.changed.wait_for(lock, timeout, [count] {
        return state.saved_events.size() >= count;
    });
}

int fail(const std::string& message) {
    std::cerr << "[SMOKE] FAILED: " << message << '\n';
    return 1;
}
}

// Test-only replacements for database, alarm and push integrations.
// They deliberately make no network/database requests and cannot touch real data.
Database::Database(std::string conninfo)
    : connection_string_(std::move(conninfo)) {}

void Database::validate_device(
    const std::string& home_id,
    const std::string& device_id
) const {
    if (home_id != "home_ci" || device_id != "door_ci") {
        throw std::runtime_error("Unexpected test device.");
    }
}

void Database::update_device_last_seen(
    const std::string&,
    const std::string&
) const {
    std::lock_guard<std::mutex> lock(state.mutex);
    ++state.last_seen_updates;
}

long long Database::save_event(const SensorEvent& event) const {
    std::lock_guard<std::mutex> lock(state.mutex);
    state.saved_events.push_back(event.event_type);
    state.changed.notify_all();
    return static_cast<long long>(state.saved_events.size());
}

AlarmRepository::AlarmRepository(std::string conninfo)
    : connection_string_(std::move(conninfo)) {}

bool AlarmRepository::resolve_device_offline_alarm(
    const std::string&,
    const std::string&
) const {
    std::lock_guard<std::mutex> lock(state.mutex);
    ++state.offline_resolutions;
    return false;
}

std::optional<Alarm> AlarmRepository::process_event(
    const SensorEvent&,
    long long
) const {
    return std::nullopt;
}

void PushNotificationService::send_alarm_notification(const Alarm&) {}

int main() {
    std::cout << std::unitbuf;

    const char* port_env = std::getenv("VEDASENTIO_SMOKE_PORT");
    if (port_env == nullptr || *port_env == '\0') {
        return fail("VEDASENTIO_SMOKE_PORT is missing.");
    }

    try {
        Database database("NO_DATABASE_CONNECTION");
        AlarmRepository alarms("NO_DATABASE_CONNECTION");

        MqttClient client(
            std::string("tcp://127.0.0.1:") + port_env,
            "vedasentio_ci_reconnect_listener",
            "vedasentio/+/+/event",
            1,
            database,
            alarms,
            nullptr
        );

        // Only a throwaway, loopback-only Mosquitto is used for this test.
        client.start("ci_smoke", "ci_smoke");
        std::cout << "[SMOKE] INITIAL_SUBSCRIBED\n";

        if (!wait_for_events(1, std::chrono::seconds(25))) {
            return fail("First event was not delivered.");
        }

        std::cout << "[SMOKE] FIRST_EVENT_SAVED\n";

        if (!wait_for_events(2, std::chrono::seconds(75))) {
            return fail("No event received after broker restart.");
        }

        // Allow queued duplicate deliveries (if any) to surface.
        std::this_thread::sleep_for(std::chrono::seconds(2));

        {
            std::lock_guard<std::mutex> lock(state.mutex);
            if (state.saved_events.size() != 2 ||
                state.saved_events[0] != "door_opened" ||
                state.saved_events[1] != "door_closed") {
                return fail("Unexpected or duplicate saved events.");
            }
            if (state.last_seen_updates != 2 ||
                state.offline_resolutions != 2) {
                return fail("Invalid MQTT payload updated the device state.");
            }
        }

        std::cout << "[SMOKE] SECOND_EVENT_SAVED\n";
        std::cout << "[SMOKE] PASS: first SUBACK, reconnect and payload validation.\n";
        return 0;
    }
    catch (const std::exception& error) {
        return fail(error.what());
    }
}
