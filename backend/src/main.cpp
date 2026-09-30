#include <mqtt/async_client.h>

#include <cstdlib>
#include <iostream>
#include <string>
#include <thread>
#include <chrono>

constexpr const char* SERVER_ADDRESS = "tcp://127.0.0.1:1883";
constexpr const char* CLIENT_ID = "vedasentio_backend";
constexpr const char* TOPIC = "vedasentio/test";
constexpr int QOS = 1;

class MqttCallback : public virtual mqtt::callback
{
public:
    void connection_lost(const std::string& cause) override
    {
        std::cerr << "[MQTT] Connection lost";

        if (!cause.empty())
            std::cerr << ": " << cause;

        std::cerr << std::endl;
    }

    void message_arrived(mqtt::const_message_ptr msg) override
    {
        std::cout << "\n[MQTT] Message received\n";
        std::cout << "Topic:   " << msg->get_topic() << '\n';
        std::cout << "Message: " << msg->to_string() << '\n';
    }
};

int main()
{
    const char* username = std::getenv("VEDASENTIO_MQTT_USER");
    const char* password = std::getenv("VEDASENTIO_MQTT_PASSWORD");

    if (!username || !password)
    {
        std::cerr
            << "Missing VEDASENTIO_MQTT_USER or "
            << "VEDASENTIO_MQTT_PASSWORD environment variable.\n";

        return 1;
    }

    try
    {
        mqtt::async_client client(SERVER_ADDRESS, CLIENT_ID);

        MqttCallback callback;
        client.set_callback(callback);

        auto connectionOptions =
            mqtt::connect_options_builder()
                .user_name(username)
                .password(password)
                .clean_session(true)
                .finalize();

        std::cout << "[VedaSentio] Backend starting...\n";
        std::cout << "[MQTT] Connecting to " << SERVER_ADDRESS << "...\n";

        client.connect(connectionOptions)->wait();

        std::cout << "[MQTT] Connected.\n";

        client.subscribe(TOPIC, QOS)->wait();

        std::cout << "[MQTT] Subscribed: " << TOPIC << '\n';
        std::cout << "[VedaSentio] Waiting for messages...\n";

        while (true)
        {
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
    }
    catch (const mqtt::exception& error)
    {
        std::cerr << "[MQTT] Error: " << error.what() << '\n';
        return 1;
    }
}