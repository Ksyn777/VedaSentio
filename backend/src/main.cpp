#include "alarms/AlarmRepository.h"
#include "api/ApiServer.h"
#include "auth/JwtService.h"
#include "database/Database.h"
#include "mqtt/MqttClient.h"
#include "security/CryptoService.h"
#include "users/UserRepository.h"

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>

namespace
{
constexpr const char* MQTT_SERVER_ADDRESS =
    "tcp://127.0.0.1:1883";

constexpr const char* MQTT_CLIENT_ID =
    "vedasentio_backend";

constexpr const char* MQTT_TOPIC_FILTER =
    "vedasentio/+/+/event";

constexpr int MQTT_QOS = 1;

constexpr const char* API_HOST =
    "127.0.0.1";

constexpr int API_PORT = 8080;

std::string require_env(
    const char* name
)
{
    const char* value =
        std::getenv(name);

    if (
        value == nullptr ||
        *value == '\0'
    )
    {
        throw std::runtime_error(
            std::string(
                "Missing required environment variable: "
            ) +
            name
        );
    }

    return value;
}

std::string quote_conninfo_value(
    const std::string& value
)
{
    std::string result;
    result.reserve(
        value.size() + 2
    );

    result.push_back('\'');

    for (char character : value)
    {
        if (
            character == '\\' ||
            character == '\''
        )
        {
            result.push_back('\\');
        }

        result.push_back(
            character
        );
    }

    result.push_back('\'');

    return result;
}

std::string build_database_connection_string()
{
    const std::string host =
        require_env(
            "VEDASENTIO_DB_HOST"
        );

    const std::string port =
        require_env(
            "VEDASENTIO_DB_PORT"
        );

    const std::string database =
        require_env(
            "VEDASENTIO_DB_NAME"
        );

    const std::string user =
        require_env(
            "VEDASENTIO_DB_USER"
        );

    const std::string password =
        require_env(
            "VEDASENTIO_DB_PASSWORD"
        );

    return
        "host=" +
        quote_conninfo_value(host) +
        " port=" +
        quote_conninfo_value(port) +
        " dbname=" +
        quote_conninfo_value(database) +
        " user=" +
        quote_conninfo_value(user) +
        " password=" +
        quote_conninfo_value(password);
}
}

int main()
{
    try
    {
        std::cout
            << "[VedaSentio] Backend starting...\n";

        const std::string mqtt_username =
            require_env(
                "VEDASENTIO_MQTT_USER"
            );

        const std::string mqtt_password =
            require_env(
                "VEDASENTIO_MQTT_PASSWORD"
            );

        const std::string database_connection_string =
            build_database_connection_string();

        CryptoService crypto(
            require_env(
                "VEDASENTIO_DATA_ENCRYPTION_KEY_B64"
            ),
            require_env(
                "VEDASENTIO_LOOKUP_HMAC_KEY_B64"
            )
        );

        JwtService jwt(
            require_env(
                "VEDASENTIO_JWT_SIGNING_KEY_B64"
            )
        );

        UserRepository users(
            database_connection_string,
            crypto
        );

        Database database(
            database_connection_string
        );

        AlarmRepository alarms(
            database_connection_string
        );

        database.test_connection();

        ApiServer api_server(
            database,
            users,
            jwt,
            alarms
        );

        std::thread api_thread(
            [&api_server]()
            {
                api_server.start(
                    API_HOST,
                    API_PORT
                );
            }
        );

        api_thread.detach();

        MqttClient mqtt_client(
            MQTT_SERVER_ADDRESS,
            MQTT_CLIENT_ID,
            MQTT_TOPIC_FILTER,
            MQTT_QOS,
            database,
            alarms
        );

        mqtt_client.start(
            mqtt_username,
            mqtt_password
        );

        std::cout
            << "[VedaSentio] Waiting for structured events...\n";

        while (true)
        {
            std::this_thread::sleep_for(
                std::chrono::seconds(1)
            );
        }
    }
    catch (const mqtt::exception& error)
    {
        std::cerr
            << "[MQTT] Error: "
            << error.what()
            << '\n';

        return 1;
    }
    catch (const std::exception& error)
    {
        std::cerr
            << "[VedaSentio] Error: "
            << error.what()
            << '\n';

        return 1;
    }
}
