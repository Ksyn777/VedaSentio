#include "../src/mqtt/MqttClient.h"
#include "../src/database/Database.h"
#include "../src/alarms/AlarmRepository.h"
#include "../src/push/PushNotificationService.h"

#include <iostream>
#include <stdexcept>

// No database or push is started; these definitions only satisfy linkage of
// the unchanged message handler. Invoking it is outside this lifecycle test.
Database::Database(std::string value) : connection_string_(value) {}
AlarmRepository::AlarmRepository(std::string value) : connection_string_(value) {}
void Database::validate_device(const std::string&, const std::string&) const { throw std::logic_error("Unexpected storage call"); }
void Database::update_device_last_seen(const std::string&, const std::string&) const { throw std::logic_error("Unexpected storage call"); }
long long Database::save_event(const SensorEvent&) const { throw std::logic_error("Unexpected storage call"); }
bool AlarmRepository::resolve_device_offline_alarm(const std::string&, const std::string&) const { throw std::logic_error("Unexpected storage call"); }
std::optional<Alarm> AlarmRepository::process_event(const SensorEvent&, long long) const { throw std::logic_error("Unexpected storage call"); }
void PushNotificationService::send_alarm_notification(const Alarm&) { throw std::logic_error("Unexpected push call"); }

void require(bool condition, const char* description) {
    if (!condition) throw std::runtime_error(description);
}

int main() {
    try {
        Database database("unused");
        AlarmRepository alarms("unused");
        MqttClient client("unused", "test", "vedasentio/+/+/event", 1, database, alarms, nullptr);
        client.start("test", "test");
        require(mqtt::test::options.minimum == 1 && mqtt::test::options.maximum == 30,
                "Paho automatic reconnect must use 1-30 seconds");
        require(mqtt::test::options.clean, "Clean session must remain enabled");
        require(mqtt::test::subscriptions == 1 && mqtt::test::subscription_waits == 1,
                "Initial connection must subscribe once and wait for SUBACK");
        client.connection_lost("test outage");
        require(mqtt::test::connects == 1 && mqtt::test::subscriptions == 1,
                "Connection loss must leave reconnect to Paho");
        mqtt::test::notify_connected();
        mqtt::test::notify_connected();
        require(mqtt::test::subscriptions == 3 && mqtt::test::subscription_waits == 1,
                "Each reconnect must subscribe asynchronously");
        require(mqtt::test::topic == "vedasentio/+/+/event" && mqtt::test::qos == 1,
                "Reconnect must preserve topic and QoS");
        mqtt::test::fail_subscription = true;
        mqtt::test::notify_connected();
        mqtt::test::fail_subscription = false;
        mqtt::test::notify_connected();
        require(mqtt::test::subscriptions == 4, "Callback must contain subscribe errors and allow later recovery");
        require(!mqtt::test::waited_in_callback, "Callbacks must never wait on tokens");
        std::cout << "[TEST] MQTT lifecycle: OK (simulated transport, no broker)\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "[TEST] " << error.what() << '\n';
        return 1;
    }
}
