#include "Database.h"

#include <pqxx/pqxx>

#include <algorithm>
#include <iostream>
#include <stdexcept>
#include <utility>

namespace
{
template <typename RowType>
EventRecord row_to_event(const RowType& row)
{
    EventRecord event;

    event.id = row["id"].template as<long long>();
    event.home_id = row["home_id"].template as<std::string>();
    event.device_id = row["device_id"].template as<std::string>();
    event.event_type = row["event_type"].template as<std::string>();
    event.value_json = row["value"].template as<std::string>();

    if (row["device_timestamp"].is_null())
    {
        event.device_timestamp = "";
    }
    else
    {
        event.device_timestamp =
            row["device_timestamp"].template as<std::string>();
    }

    event.received_at =
        row["received_at"].template as<std::string>();

    return event;
}
}

Database::Database(std::string connection_string)
    : connection_string_(std::move(connection_string))
{
}

void Database::test_connection() const
{
    pqxx::connection connection(connection_string_);

    if (!connection.is_open())
    {
        throw std::runtime_error(
            "Unable to open PostgreSQL connection."
        );
    }

    std::cout << "[DB] Connected to PostgreSQL.\n";
}

void Database::validate_device(
    const std::string& home_id,
    const std::string& device_id
) const
{
    pqxx::connection connection(connection_string_);

    if (!connection.is_open())
    {
        throw std::runtime_error(
            "Unable to open PostgreSQL connection."
        );
    }

    pqxx::work transaction(connection);

    const pqxx::result result = transaction.exec(
        "SELECT is_active FROM devices WHERE home_id = $1 AND id = $2",
        pqxx::params{
            home_id,
            device_id
        }
    );

    transaction.commit();

    if (result.empty())
    {
        throw std::runtime_error(
            "Device '" + device_id +
            "' is not registered in home '" +
            home_id + "'."
        );
    }

    if (!result[0]["is_active"].as<bool>())
    {
        throw std::runtime_error(
            "Device '" + device_id +
            "' is inactive."
        );
    }
}

long long Database::save_event(
    const SensorEvent& event
) const
{
    pqxx::connection connection(connection_string_);

    if (!connection.is_open())
    {
        throw std::runtime_error(
            "Unable to open PostgreSQL connection."
        );
    }

    pqxx::work transaction(connection);

    const pqxx::result result = transaction.exec(
        R"SQL(
            INSERT INTO sensor_events
            (
                topic,
                payload,
                home_id,
                device_id,
                event_type,
                value,
                device_timestamp
            )
            VALUES
            (
                $1,
                $2,
                $3,
                $4,
                $5,
                $6::jsonb,
                $7::timestamptz
            )
            RETURNING id
        )SQL",
        pqxx::params{
            event.topic,
            event.raw_payload,
            event.home_id,
            event.device_id,
            event.event_type,
            event.value_json,
            event.device_timestamp
        }
    );

    const long long event_id =
        result[0]["id"].as<long long>();

    transaction.commit();

    std::cout << "[DB] Structured event saved. id="
              << event_id
              << "\n";

    return event_id;
}

std::vector<Home> Database::get_homes() const
{
    pqxx::connection connection(connection_string_);
    pqxx::read_transaction transaction(connection);

    const pqxx::result result = transaction.exec(
        "SELECT id, name, created_at::text AS created_at "
        "FROM homes "
        "ORDER BY id"
    );

    std::vector<Home> homes;
    homes.reserve(result.size());

    for (const auto& row : result)
    {
        Home home;

        home.id =
            row["id"].as<std::string>();

        home.name =
            row["name"].as<std::string>();

        home.created_at =
            row["created_at"].as<std::string>();

        homes.push_back(
            std::move(home)
        );
    }

    return homes;
}

std::vector<Device> Database::get_devices(
    const std::string& home_id
) const
{
    pqxx::connection connection(connection_string_);
    pqxx::read_transaction transaction(connection);

    const pqxx::result result = transaction.exec(
        R"SQL(
            SELECT
                home_id,
                id,
                device_type,
                name,
                is_active,
                created_at::text AS created_at
            FROM devices
            WHERE home_id = $1
            ORDER BY id
        )SQL",
        pqxx::params{
            home_id
        }
    );

    std::vector<Device> devices;
    devices.reserve(result.size());

    for (const auto& row : result)
    {
        Device device;

        device.home_id =
            row["home_id"].as<std::string>();

        device.id =
            row["id"].as<std::string>();

        device.device_type =
            row["device_type"].as<std::string>();

        device.name =
            row["name"].as<std::string>();

        device.is_active =
            row["is_active"].as<bool>();

        device.created_at =
            row["created_at"].as<std::string>();

        devices.push_back(
            std::move(device)
        );
    }

    return devices;
}

std::vector<EventRecord> Database::get_events(
    const std::string& home_id,
    int limit
) const
{
    limit = std::clamp(
        limit,
        1,
        500
    );

    pqxx::connection connection(connection_string_);
    pqxx::read_transaction transaction(connection);

    const pqxx::result result = transaction.exec(
        R"SQL(
            SELECT
                id,
                home_id,
                device_id,
                event_type,
                value::text AS value,
                device_timestamp::text AS device_timestamp,
                received_at::text AS received_at
            FROM sensor_events
            WHERE home_id = $1
            ORDER BY received_at DESC
            LIMIT $2
        )SQL",
        pqxx::params{
            home_id,
            limit
        }
    );

    std::vector<EventRecord> events;
    events.reserve(result.size());

    for (const auto& row : result)
    {
        events.push_back(
            row_to_event(row)
        );
    }

    return events;
}

std::optional<EventRecord> Database::get_latest_event(
    const std::string& home_id,
    const std::string& device_id
) const
{
    pqxx::connection connection(connection_string_);
    pqxx::read_transaction transaction(connection);

    const pqxx::result result = transaction.exec(
        R"SQL(
            SELECT
                id,
                home_id,
                device_id,
                event_type,
                value::text AS value,
                device_timestamp::text AS device_timestamp,
                received_at::text AS received_at
            FROM sensor_events
            WHERE home_id = $1
              AND device_id = $2
            ORDER BY received_at DESC
            LIMIT 1
        )SQL",
        pqxx::params{
            home_id,
            device_id
        }
    );

    if (result.empty())
    {
        return std::nullopt;
    }

    return row_to_event(
        result[0]
    );
}


void Database::save_mobile_push_notification_token(
    long long user_id,
    const std::string& firebase_cloud_messaging_token,
    const std::string& mobile_platform
) const
{
    pqxx::connection connection(connection_string_);

    if (!connection.is_open())
    {
        throw std::runtime_error(
            "Unable to open PostgreSQL connection."
        );
    }

    pqxx::work transaction(connection);

    transaction.exec(
        R"SQL(
            INSERT INTO mobile_push_tokens
            (
                user_id,
                fcm_token,
                platform,
                is_active,
                last_registered_at,
                updated_at
            )
            VALUES
            (
                $1,
                $2,
                $3,
                TRUE,
                NOW(),
                NOW()
            )
            ON CONFLICT (fcm_token)
            DO UPDATE SET
                user_id = EXCLUDED.user_id,
                platform = EXCLUDED.platform,
                is_active = TRUE,
                last_registered_at = NOW(),
                updated_at = NOW()
        )SQL",
        pqxx::params{
            user_id,
            firebase_cloud_messaging_token,
            mobile_platform
        }
    );

    transaction.commit();
}
