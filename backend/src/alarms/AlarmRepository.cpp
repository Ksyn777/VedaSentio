#include "AlarmRepository.h"

#include <nlohmann/json.hpp>
#include <pqxx/pqxx>

#include <algorithm>
#include <iostream>
#include <stdexcept>
#include <utility>

namespace
{
struct AlarmRule
{
    std::string alarm_type;
    std::string severity;
    bool opens_alarm = false;
    bool resolves_alarm = false;
};

std::optional<AlarmRule> rule_for_event(
    const std::string& event_type
)
{
    if (event_type == "sos_pressed")
        return AlarmRule{"sos", "critical", true, false};
    if (event_type == "sos_resolved")
        return AlarmRule{"sos", "critical", false, true};

    if (event_type == "smoke_detected")
        return AlarmRule{"smoke", "critical", true, false};
    if (event_type == "smoke_cleared")
        return AlarmRule{"smoke", "critical", false, true};

    if (event_type == "co_detected")
        return AlarmRule{"co", "critical", true, false};
    if (event_type == "co_cleared")
        return AlarmRule{"co", "critical", false, true};

    if (event_type == "gas_detected")
        return AlarmRule{"gas", "critical", true, false};
    if (event_type == "gas_cleared")
        return AlarmRule{"gas", "critical", false, true};

    if (event_type == "flood_detected")
        return AlarmRule{"flood", "warning", true, false};
    if (event_type == "flood_cleared")
        return AlarmRule{"flood", "warning", false, true};

    return std::nullopt;
}

bool event_value_is_active(
    const std::string& value_json
)
{
    try
    {
        const auto value = nlohmann::json::parse(value_json);

        if (value.is_boolean())
            return value.get<bool>();

        if (value.is_number())
            return value.get<double>() != 0.0;

        if (value.is_string())
        {
            const std::string text = value.get<std::string>();
            return text == "true" || text == "1" ||
                   text == "active" || text == "alarm";
        }

        if (value.is_object() && value.contains("active"))
        {
            const auto& active = value["active"];
            if (active.is_boolean())
                return active.get<bool>();
        }
    }
    catch (...)
    {
        return false;
    }

    return false;
}

template <typename RowType>
Alarm row_to_alarm(const RowType& row)
{
    Alarm alarm;

    alarm.id = row["id"].template as<long long>();
    alarm.home_id = row["home_id"].template as<std::string>();
    alarm.device_id = row["device_id"].template as<std::string>();
    alarm.alarm_type = row["alarm_type"].template as<std::string>();
    alarm.severity = row["severity"].template as<std::string>();
    alarm.status = row["status"].template as<std::string>();

    if (!row["source_event_id"].is_null())
        alarm.source_event_id = row["source_event_id"].template as<long long>();

    if (!row["last_event_id"].is_null())
        alarm.last_event_id = row["last_event_id"].template as<long long>();

    alarm.started_at = row["started_at"].template as<std::string>();

    if (!row["acknowledged_at"].is_null())
        alarm.acknowledged_at = row["acknowledged_at"].template as<std::string>();

    if (!row["acknowledged_by"].is_null())
        alarm.acknowledged_by = row["acknowledged_by"].template as<long long>();

    if (!row["resolved_at"].is_null())
        alarm.resolved_at = row["resolved_at"].template as<std::string>();

    if (!row["resolved_by"].is_null())
        alarm.resolved_by = row["resolved_by"].template as<long long>();

    if (!row["resolution_source"].is_null())
        alarm.resolution_source = row["resolution_source"].template as<std::string>();

    alarm.created_at = row["created_at"].template as<std::string>();
    alarm.updated_at = row["updated_at"].template as<std::string>();

    return alarm;
}

std::string alarm_select_columns()
{
    return R"SQL(
        id,
        home_id,
        device_id,
        alarm_type,
        severity,
        status,
        source_event_id,
        last_event_id,
        started_at::text AS started_at,
        acknowledged_at::text AS acknowledged_at,
        acknowledged_by,
        resolved_at::text AS resolved_at,
        resolved_by,
        resolution_source,
        created_at::text AS created_at,
        updated_at::text AS updated_at
    )SQL";
}
}

AlarmRepository::AlarmRepository(
    std::string connection_string
)
    : connection_string_(
        std::move(connection_string)
      )
{
}

void AlarmRepository::process_event(
    const SensorEvent& event,
    long long event_id
) const
{
    const auto rule = rule_for_event(event.event_type);

    if (!rule.has_value())
        return;

    pqxx::connection connection(connection_string_);
    pqxx::work transaction(connection);

    if (rule->opens_alarm)
    {
        if (!event_value_is_active(event.value_json))
        {
            std::cout
                << "[ALARM] Ignored inactive value for "
                << event.event_type
                << ".\n";
            return;
        }

        const pqxx::result existing = transaction.exec(
            R"SQL(
                SELECT id
                FROM alarms
                WHERE home_id = $1
                  AND device_id = $2
                  AND alarm_type = $3
                  AND status IN ('active', 'acknowledged')
                ORDER BY id DESC
                LIMIT 1
                FOR UPDATE
            )SQL",
            pqxx::params{
                event.home_id,
                event.device_id,
                rule->alarm_type
            }
        );

        if (existing.empty())
        {
            transaction.exec(
                R"SQL(
                    INSERT INTO alarms
                    (
                        home_id,
                        device_id,
                        alarm_type,
                        severity,
                        status,
                        source_event_id,
                        last_event_id
                    )
                    VALUES
                    (
                        $1,
                        $2,
                        $3,
                        $4,
                        'active',
                        $5,
                        $5
                    )
                )SQL",
                pqxx::params{
                    event.home_id,
                    event.device_id,
                    rule->alarm_type,
                    rule->severity,
                    event_id
                }
            );

            std::cout
                << "[ALARM] Opened type="
                << rule->alarm_type
                << " severity="
                << rule->severity
                << ".\n";
        }
        else
        {
            transaction.exec(
                R"SQL(
                    UPDATE alarms
                    SET
                        last_event_id = $1,
                        updated_at = NOW()
                    WHERE id = $2
                )SQL",
                pqxx::params{
                    event_id,
                    existing[0]["id"].as<long long>()
                }
            );

            std::cout
                << "[ALARM] Existing open alarm updated.\n";
        }
    }
    else if (rule->resolves_alarm)
    {
        const pqxx::result resolved = transaction.exec(
            R"SQL(
                UPDATE alarms
                SET
                    status = 'resolved',
                    resolved_at = NOW(),
                    resolution_source = 'sensor',
                    last_event_id = $1,
                    updated_at = NOW()
                WHERE home_id = $2
                  AND device_id = $3
                  AND alarm_type = $4
                  AND status IN ('active', 'acknowledged')
                RETURNING id
            )SQL",
            pqxx::params{
                event_id,
                event.home_id,
                event.device_id,
                rule->alarm_type
            }
        );

        if (!resolved.empty())
        {
            std::cout
                << "[ALARM] Resolved type="
                << rule->alarm_type
                << " from sensor event.\n";
        }
    }

    transaction.commit();
}

std::vector<Alarm> AlarmRepository::get_alarms(
    const std::string& home_id,
    bool active_only,
    int limit
) const
{
    limit = std::clamp(limit, 1, 500);

    pqxx::connection connection(connection_string_);
    pqxx::read_transaction transaction(connection);

    const std::string where_status = active_only
        ? " AND status IN ('active', 'acknowledged') "
        : " ";

    const std::string sql =
        "SELECT " + alarm_select_columns() +
        " FROM alarms WHERE home_id = $1 " +
        where_status +
        " ORDER BY started_at DESC LIMIT $2";

    const pqxx::result result = transaction.exec(
        sql,
        pqxx::params{home_id, limit}
    );

    std::vector<Alarm> alarms;
    alarms.reserve(result.size());

    for (const auto& row : result)
        alarms.push_back(row_to_alarm(row));

    return alarms;
}

std::optional<Alarm> AlarmRepository::acknowledge_alarm(
    const std::string& home_id,
    long long alarm_id,
    long long user_id
) const
{
    pqxx::connection connection(connection_string_);
    pqxx::work transaction(connection);

    pqxx::result result = transaction.exec(
        "UPDATE alarms SET "
        "status = 'acknowledged', "
        "acknowledged_at = COALESCE(acknowledged_at, NOW()), "
        "acknowledged_by = COALESCE(acknowledged_by, $1), "
        "updated_at = NOW() "
        "WHERE id = $2 AND home_id = $3 AND status = 'active' "
        "RETURNING " + alarm_select_columns(),
        pqxx::params{user_id, alarm_id, home_id}
    );

    if (result.empty())
    {
        result = transaction.exec(
            "SELECT " + alarm_select_columns() +
            " FROM alarms "
            "WHERE id = $1 AND home_id = $2 "
            "AND status = 'acknowledged' LIMIT 1",
            pqxx::params{alarm_id, home_id}
        );
    }

    transaction.commit();

    if (result.empty())
        return std::nullopt;

    return row_to_alarm(result[0]);
}
