#include "Database.h"

#include <pqxx/pqxx>

#include <iostream>
#include <stdexcept>
#include <utility>

Database::Database(std::string connection_string)
    : connection_string_(std::move(connection_string))
{
}

void Database::test_connection() const
{
    pqxx::connection connection(connection_string_);

    if (!connection.is_open())
    {
        throw std::runtime_error("Unable to open PostgreSQL connection.");
    }

    std::cout << "[DB] Connected to PostgreSQL.\n";
}

void Database::save_event(
    const std::string& topic,
    const std::string& payload
) const
{
    pqxx::connection connection(connection_string_);

    if (!connection.is_open())
    {
        throw std::runtime_error("Unable to open PostgreSQL connection.");
    }

    pqxx::work transaction(connection);

    transaction.exec(
        "INSERT INTO sensor_events (topic, payload) VALUES ($1, $2)",
        pqxx::params{topic, payload}
    );

    transaction.commit();

    std::cout << "[DB] Event saved.\n";
}
