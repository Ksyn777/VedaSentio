#include "MqttClient.h"
#include "SensorEventParser.h"

#include "../alarms/AlarmRepository.h"
#include "../database/Database.h"
#include "../push/PushNotificationService.h"

#include <chrono>
#include <exception>
#include <iostream>
#include <utility>

MqttClient::MqttClient(
    std::string server_address,
    std::string client_id,
    std::string topic_filter,
    int qos,
    Database& database,
    AlarmRepository& alarms,
    PushNotificationService* push_notifications
)
    : server_address_(
          std::move(
              server_address
          )
      ),
      topic_filter_(
          std::move(
              topic_filter
          )
      ),
      qos_(
          qos
      ),
      database_(
          database
      ),
      alarms_(
          alarms
      ),
      push_notifications_(
          push_notifications
      ),
      client_(
          server_address_,
          std::move(
              client_id
          )
      )
{
    client_.set_callback(
        *this
    );
}

void MqttClient::start(
    const std::string& username,
    const std::string& password
)
{
    auto connection_options =
        mqtt::connect_options_builder()
            .user_name(
                username
            )
            .password(
                password
            )
            .clean_session(
                true
            )
            .automatic_reconnect(
                std::chrono::seconds(1),
                std::chrono::seconds(30)
            )
            .finalize();

    std::cout
        << "[MQTT] Connecting to "
        << server_address_
        << "...\n";

    client_
        .connect(
            connection_options
        )
        ->wait();

    std::cout
        << "[MQTT] Connected.\n";

    // Initial subscribe must be acknowledged before processing events.
    client_
        .subscribe(
            topic_filter_,
            qos_
        )
        ->wait();

    std::cout
        << "[MQTT] Subscribed: "
        << topic_filter_
        << '\n';
}

void MqttClient::connected(
    const std::string& cause
)
{
    try
    {
        client_.subscribe(
            topic_filter_,
            qos_
        );

        std::cout
            << "[MQTT] Subscription requested: "
            << topic_filter_;

        if (!cause.empty())
        {
            std::cout
                << " ("
                << cause
                << ")";
        }

        std::cout
            << '\n';
    }
    catch (const mqtt::exception& error)
    {
        std::cerr
            << "[MQTT] Subscription request failed: "
            << error.what()
            << '\n';
    }
}

void MqttClient::connection_lost(
    const std::string& cause
)
{
    std::cerr
        << "[MQTT] Connection lost";

    if (!cause.empty())
    {
        std::cerr
            << ": "
            << cause;
    }

    std::cerr
        << "\n[MQTT] Automatic reconnect is enabled.\n";
}

void MqttClient::message_arrived(
    mqtt::const_message_ptr message
)
{
    const std::string topic =
        message->get_topic();

    const std::string payload =
        message->to_string();

    std::cout
        << "\n[MQTT] Message received\n";

    std::cout
        << "Topic:   "
        << topic
        << '\n';

    std::cout
        << "Payload: "
        << payload
        << '\n';

    try
    {
        const SensorEvent event =
            parse_sensor_event(
                topic,
                payload
            );

        std::cout
            << "[EVENT] home_id="
            << event.home_id
            << " device_id="
            << event.device_id
            << " event_type="
            << event.event_type
            << '\n';

        database_.validate_device(
            event.home_id,
            event.device_id
        );

        std::cout
            << "[DEVICE] Registered and active.\n";

        database_.update_device_last_seen(
            event.home_id,
            event.device_id
        );

        alarms_.resolve_device_offline_alarm(
            event.home_id,
            event.device_id
        );

        if (event.event_type == "heartbeat")
        {
            std::cout
                << "[HEARTBEAT] Device last_seen updated.\n";

            return;
        }

        const long long event_id =
            database_.save_event(
                event
            );

        const auto newly_opened_alarm =
            alarms_.process_event(
                event,
                event_id
            );

        if (
            newly_opened_alarm.has_value() &&
            push_notifications_ != nullptr
        )
        {
            try
            {
                push_notifications_
                    ->send_alarm_notification(
                        newly_opened_alarm.value()
                    );
            }
            catch (const std::exception& push_error)
            {
                std::cerr
                    << "[PUSH] Alarm saved, but notification failed: "
                    << push_error.what()
                    << '\n';
            }
        }
    }
    catch (const std::exception& error)
    {
        std::cerr
            << "[EVENT] Rejected: "
            << error.what()
            << '\n';
    }
}
