#include "ApiServer.h"

#include "../alarms/AlarmRepository.h"
#include "../auth/JwtService.h"
#include "../database/Database.h"
#include "../model/Alarm.h"
#include "../model/User.h"
#include "../users/UserRepository.h"

#include <httplib.h>
#include <nlohmann/json.hpp>

#include <iostream>
#include <optional>
#include <string>
#include <unordered_map>

namespace
{
constexpr long long ACCESS_TOKEN_LIFETIME_SECONDS =
    3600;

void apply_security_headers(
    httplib::Response& response
)
{
    response.set_header(
        "Cache-Control",
        "no-store"
    );

    response.set_header(
        "Pragma",
        "no-cache"
    );

    response.set_header(
        "X-Content-Type-Options",
        "nosniff"
    );
}

void send_json(
    httplib::Response& response,
    const nlohmann::json& body,
    int status = 200
)
{
    response.status =
        status;

    apply_security_headers(
        response
    );

    response.set_content(
        body.dump(2),
        "application/json; charset=utf-8"
    );
}

nlohmann::json user_to_json(
    const User& user
)
{
    return {
        {"id", user.id},
        {"email", user.email},
        {"first_name", user.first_name},
        {"last_name", user.last_name},
        {"phone", user.phone},
        {"is_active", user.is_active},
        {"created_at", user.created_at}
    };
}

nlohmann::json event_to_json(
    const EventRecord& event
)
{
    nlohmann::json value;

    try
    {
        value =
            nlohmann::json::parse(
                event.value_json
            );
    }
    catch (...)
    {
        value =
            event.value_json;
    }

    return {
        {"id", event.id},
        {"home_id", event.home_id},
        {"device_id", event.device_id},
        {"event_type", event.event_type},
        {"value", value},
        {"device_timestamp", event.device_timestamp},
        {"received_at", event.received_at}
    };
}


nlohmann::json alarm_to_json(
    const Alarm& alarm
)
{
    nlohmann::json body = {
        {"id", alarm.id},
        {"home_id", alarm.home_id},
        {"device_id", alarm.device_id},
        {"alarm_type", alarm.alarm_type},
        {"severity", alarm.severity},
        {"status", alarm.status},
        {"started_at", alarm.started_at},
        {"created_at", alarm.created_at},
        {"updated_at", alarm.updated_at}
    };

    body["source_event_id"] = alarm.source_event_id.has_value()
        ? nlohmann::json(*alarm.source_event_id)
        : nlohmann::json(nullptr);

    body["last_event_id"] = alarm.last_event_id.has_value()
        ? nlohmann::json(*alarm.last_event_id)
        : nlohmann::json(nullptr);

    body["acknowledged_at"] = alarm.acknowledged_at.empty()
        ? nlohmann::json(nullptr)
        : nlohmann::json(alarm.acknowledged_at);

    body["acknowledged_by"] = alarm.acknowledged_by.has_value()
        ? nlohmann::json(*alarm.acknowledged_by)
        : nlohmann::json(nullptr);

    body["resolved_at"] = alarm.resolved_at.empty()
        ? nlohmann::json(nullptr)
        : nlohmann::json(alarm.resolved_at);

    body["resolved_by"] = alarm.resolved_by.has_value()
        ? nlohmann::json(*alarm.resolved_by)
        : nlohmann::json(nullptr);

    body["resolution_source"] = alarm.resolution_source.empty()
        ? nlohmann::json(nullptr)
        : nlohmann::json(alarm.resolution_source);

    return body;
}

std::optional<std::string> home_role(
    long long user_id,
    const std::string& home_id,
    UserRepository& users
)
{
    for (const auto& membership : users.get_home_memberships(user_id))
    {
        if (membership.home_id == home_id)
            return membership.role;
    }

    return std::nullopt;
}

bool require_alarm_management_role(
    const User& user,
    const std::string& home_id,
    httplib::Response& response,
    UserRepository& users
)
{
    const auto role = home_role(user.id, home_id, users);

    if (role.has_value() &&
        (*role == "owner" || *role == "caregiver"))
    {
        return true;
    }

    send_json(
        response,
        {{"error", "Alarm management requires owner or caregiver role."}},
        403
    );

    return false;
}

std::optional<std::string> bearer_token(
    const httplib::Request& request
)
{
    const std::string authorization =
        request.get_header_value(
            "Authorization"
        );

    constexpr const char* prefix =
        "Bearer ";

    const std::string prefix_string =
        prefix;

    if (
        authorization.size() <=
            prefix_string.size() ||
        authorization.compare(
            0,
            prefix_string.size(),
            prefix_string
        ) != 0
    )
    {
        return std::nullopt;
    }

    const std::string token =
        authorization.substr(
            prefix_string.size()
        );

    if (token.empty())
    {
        return std::nullopt;
    }

    return token;
}

std::optional<User> authenticated_user(
    const httplib::Request& request,
    httplib::Response& response,
    UserRepository& users,
    JwtService& jwt
)
{
    const auto token =
        bearer_token(request);

    if (!token.has_value())
    {
        response.set_header(
            "WWW-Authenticate",
            "Bearer"
        );

        send_json(
            response,
            {
                {"error", "Authentication required."}
            },
            401
        );

        return std::nullopt;
    }

    try
    {
        const JwtClaims claims =
            jwt.verify_access_token(
                *token
            );

        const auto user =
            users.get_by_id(
                claims.user_id
            );

        if (
            !user.has_value() ||
            !user->is_active
        )
        {
            response.set_header(
                "WWW-Authenticate",
                "Bearer"
            );

            send_json(
                response,
                {
                    {"error", "Invalid authentication token."}
                },
                401
            );

            return std::nullopt;
        }

        return user;
    }
    catch (...)
    {
        response.set_header(
            "WWW-Authenticate",
            "Bearer"
        );

        send_json(
            response,
            {
                {"error", "Invalid or expired authentication token."}
            },
            401
        );

        return std::nullopt;
    }
}

bool require_home_access(
    const User& user,
    const std::string& home_id,
    httplib::Response& response,
    UserRepository& users
)
{
    if (
        users.has_home_access(
            user.id,
            home_id
        )
    )
    {
        return true;
    }

    send_json(
        response,
        {
            {"error", "Access denied."}
        },
        403
    );

    return false;
}
}

ApiServer::ApiServer(
    Database& database,
    UserRepository& users,
    JwtService& jwt,
    AlarmRepository& alarms
)
    : database_(database),
      users_(users),
      jwt_(jwt),
      alarms_(alarms)
{
}

void ApiServer::start(
    const std::string& host,
    int port
)
{
    httplib::Server server;

    server.Get(
        "/api/health",
        [](
            const httplib::Request&,
            httplib::Response& response
        )
        {
            send_json(
                response,
                {
                    {"status", "ok"},
                    {"service", "vedasentio-backend"}
                }
            );
        }
    );

    server.Post(
        "/api/auth/login",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            try
            {
                if (request.body.size() > 8192)
                {
                    send_json(
                        response,
                        {
                            {"error", "Request body is too large."}
                        },
                        413
                    );

                    return;
                }

                nlohmann::json body;

                try
                {
                    body =
                        nlohmann::json::parse(
                            request.body
                        );
                }
                catch (...)
                {
                    send_json(
                        response,
                        {
                            {"error", "Invalid JSON body."}
                        },
                        400
                    );

                    return;
                }

                if (
                    !body.contains("email") ||
                    !body["email"].is_string() ||
                    !body.contains("password") ||
                    !body["password"].is_string()
                )
                {
                    send_json(
                        response,
                        {
                            {"error", "E-mail and password are required."}
                        },
                        400
                    );

                    return;
                }

                const std::string email =
                    body["email"]
                        .get<std::string>();

                const std::string password =
                    body["password"]
                        .get<std::string>();

                if (
                    email.empty() ||
                    email.size() > 320 ||
                    password.empty() ||
                    password.size() > 1024
                )
                {
                    send_json(
                        response,
                        {
                            {"error", "Invalid credentials."}
                        },
                        401
                    );

                    return;
                }

                std::optional<User> user;

                try
                {
                    user =
                        users_.authenticate(
                            email,
                            password
                        );
                }
                catch (...)
                {
                    user =
                        std::nullopt;
                }

                if (!user.has_value())
                {
                    send_json(
                        response,
                        {
                            {"error", "Invalid credentials."}
                        },
                        401
                    );

                    return;
                }

                const std::string token =
                    jwt_.create_access_token(
                        user->id,
                        ACCESS_TOKEN_LIFETIME_SECONDS
                    );

                send_json(
                    response,
                    {
                        {
                            "access_token",
                            token
                        },
                        {
                            "token_type",
                            "Bearer"
                        },
                        {
                            "expires_in",
                            ACCESS_TOKEN_LIFETIME_SECONDS
                        },
                        {
                            "user",
                            user_to_json(*user)
                        }
                    }
                );
            }
            catch (const std::exception& error)
            {
                std::cerr
                    << "[API] Login error: "
                    << error.what()
                    << '\n';

                send_json(
                    response,
                    {
                        {"error", "Authentication service error."}
                    },
                    500
                );
            }
        }
    );

    server.Get(
        "/api/me",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            const auto user =
                authenticated_user(
                    request,
                    response,
                    users_,
                    jwt_
                );

            if (!user.has_value())
            {
                return;
            }

            try
            {
                nlohmann::json memberships =
                    nlohmann::json::array();

                for (
                    const auto& membership :
                    users_.get_home_memberships(
                        user->id
                    )
                )
                {
                    memberships.push_back(
                        {
                            {
                                "home_id",
                                membership.home_id
                            },
                            {
                                "role",
                                membership.role
                            }
                        }
                    );
                }

                nlohmann::json body =
                    user_to_json(*user);

                body["homes"] =
                    memberships;

                send_json(
                    response,
                    body
                );
            }
            catch (const std::exception& error)
            {
                std::cerr
                    << "[API] /api/me error: "
                    << error.what()
                    << '\n';

                send_json(
                    response,
                    {
                        {"error", "Unable to load user profile."}
                    },
                    500
                );
            }
        }
    );

    server.Get(
        "/api/homes",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            const auto user =
                authenticated_user(
                    request,
                    response,
                    users_,
                    jwt_
                );

            if (!user.has_value())
            {
                return;
            }

            try
            {
                std::unordered_map<
                    std::string,
                    std::string
                > role_by_home;

                for (
                    const auto& membership :
                    users_.get_home_memberships(
                        user->id
                    )
                )
                {
                    role_by_home[
                        membership.home_id
                    ] =
                        membership.role;
                }

                nlohmann::json body =
                    nlohmann::json::array();

                for (
                    const auto& home :
                    database_.get_homes()
                )
                {
                    const auto role =
                        role_by_home.find(
                            home.id
                        );

                    if (
                        role ==
                        role_by_home.end()
                    )
                    {
                        continue;
                    }

                    body.push_back(
                        {
                            {"id", home.id},
                            {"name", home.name},
                            {"role", role->second},
                            {
                                "created_at",
                                home.created_at
                            }
                        }
                    );
                }

                send_json(
                    response,
                    body
                );
            }
            catch (const std::exception& error)
            {
                std::cerr
                    << "[API] /api/homes error: "
                    << error.what()
                    << '\n';

                send_json(
                    response,
                    {
                        {"error", "Unable to load homes."}
                    },
                    500
                );
            }
        }
    );

    server.Get(
        R"(/api/homes/([^/]+)/devices)",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            const auto user =
                authenticated_user(
                    request,
                    response,
                    users_,
                    jwt_
                );

            if (!user.has_value())
            {
                return;
            }

            try
            {
                const std::string home_id =
                    request.matches[1];

                if (
                    !require_home_access(
                        *user,
                        home_id,
                        response,
                        users_
                    )
                )
                {
                    return;
                }

                nlohmann::json body =
                    nlohmann::json::array();

                for (
                    const auto& device :
                    database_.get_devices(
                        home_id
                    )
                )
                {
                    body.push_back(
                        {
                            {
                                "home_id",
                                device.home_id
                            },
                            {
                                "id",
                                device.id
                            },
                            {
                                "device_type",
                                device.device_type
                            },
                            {
                                "name",
                                device.name
                            },
                            {
                                "is_active",
                                device.is_active
                            },
                            {
                                "last_seen_at",
                                device.last_seen_at.empty()
                                    ? nlohmann::json(nullptr)
                                    : nlohmann::json(device.last_seen_at)
                            },
                            {
                                "is_online",
                                device.is_online
                            },
                            {
                                "created_at",
                                device.created_at
                            }
                        }
                    );
                }

                send_json(
                    response,
                    body
                );
            }
            catch (const std::exception& error)
            {
                std::cerr
                    << "[API] devices error: "
                    << error.what()
                    << '\n';

                send_json(
                    response,
                    {
                        {"error", "Unable to load devices."}
                    },
                    500
                );
            }
        }
    );

    server.Get(
        R"(/api/homes/([^/]+)/events)",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            const auto user =
                authenticated_user(
                    request,
                    response,
                    users_,
                    jwt_
                );

            if (!user.has_value())
            {
                return;
            }

            try
            {
                const std::string home_id =
                    request.matches[1];

                if (
                    !require_home_access(
                        *user,
                        home_id,
                        response,
                        users_
                    )
                )
                {
                    return;
                }

                int limit = 100;

                if (
                    request.has_param(
                        "limit"
                    )
                )
                {
                    try
                    {
                        limit =
                            std::stoi(
                                request.get_param_value(
                                    "limit"
                                )
                            );
                    }
                    catch (...)
                    {
                        send_json(
                            response,
                            {
                                {"error", "Invalid limit parameter."}
                            },
                            400
                        );

                        return;
                    }
                }

                nlohmann::json body =
                    nlohmann::json::array();

                for (
                    const auto& event :
                    database_.get_events(
                        home_id,
                        limit
                    )
                )
                {
                    body.push_back(
                        event_to_json(event)
                    );
                }

                send_json(
                    response,
                    body
                );
            }
            catch (const std::exception& error)
            {
                std::cerr
                    << "[API] events error: "
                    << error.what()
                    << '\n';

                send_json(
                    response,
                    {
                        {"error", "Unable to load events."}
                    },
                    500
                );
            }
        }
    );

    server.Get(
        R"(/api/homes/([^/]+)/devices/([^/]+)/latest)",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            const auto user =
                authenticated_user(
                    request,
                    response,
                    users_,
                    jwt_
                );

            if (!user.has_value())
            {
                return;
            }

            try
            {
                const std::string home_id =
                    request.matches[1];

                const std::string device_id =
                    request.matches[2];

                if (
                    !require_home_access(
                        *user,
                        home_id,
                        response,
                        users_
                    )
                )
                {
                    return;
                }

                const auto event =
                    database_.get_latest_event(
                        home_id,
                        device_id
                    );

                if (!event.has_value())
                {
                    send_json(
                        response,
                        {
                            {"error", "No event found."}
                        },
                        404
                    );

                    return;
                }

                send_json(
                    response,
                    event_to_json(*event)
                );
            }
            catch (const std::exception& error)
            {
                std::cerr
                    << "[API] latest event error: "
                    << error.what()
                    << '\n';

                send_json(
                    response,
                    {
                        {"error", "Unable to load latest event."}
                    },
                    500
                );
            }
        }
    );


    server.Get(
        R"(/api/homes/([^/]+)/alarms)",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            const auto user = authenticated_user(
                request,
                response,
                users_,
                jwt_
            );

            if (!user.has_value())
                return;

            try
            {
                const std::string home_id = request.matches[1];

                if (!require_home_access(
                        *user,
                        home_id,
                        response,
                        users_
                    ))
                {
                    return;
                }

                bool active_only = false;
                int limit = 100;

                if (request.has_param("active"))
                {
                    const std::string value =
                        request.get_param_value("active");

                    active_only =
                        value == "true" ||
                        value == "1";
                }

                if (request.has_param("limit"))
                {
                    try
                    {
                        limit = std::stoi(
                            request.get_param_value("limit")
                        );
                    }
                    catch (...)
                    {
                        send_json(
                            response,
                            {{"error", "Invalid limit parameter."}},
                            400
                        );
                        return;
                    }
                }

                nlohmann::json body = nlohmann::json::array();

                for (const auto& alarm : alarms_.get_alarms(
                         home_id,
                         active_only,
                         limit
                     ))
                {
                    body.push_back(alarm_to_json(alarm));
                }

                send_json(response, body);
            }
            catch (const std::exception& error)
            {
                std::cerr
                    << "[API] alarms error: "
                    << error.what()
                    << '\n';

                send_json(
                    response,
                    {{"error", "Unable to load alarms."}},
                    500
                );
            }
        }
    );

    server.Post(
        R"(/api/homes/([^/]+)/alarms/([0-9]+)/acknowledge)",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            const auto user = authenticated_user(
                request,
                response,
                users_,
                jwt_
            );

            if (!user.has_value())
                return;

            try
            {
                const std::string home_id = request.matches[1];
                const long long alarm_id = std::stoll(request.matches[2].str());

                if (!require_home_access(
                        *user,
                        home_id,
                        response,
                        users_
                    ))
                {
                    return;
                }

                if (!require_alarm_management_role(
                        *user,
                        home_id,
                        response,
                        users_
                    ))
                {
                    return;
                }

                const auto alarm = alarms_.acknowledge_alarm(
                    home_id,
                    alarm_id,
                    user->id
                );

                if (!alarm.has_value())
                {
                    send_json(
                        response,
                        {{"error", "Active alarm not found."}},
                        404
                    );
                    return;
                }

                send_json(
                    response,
                    alarm_to_json(*alarm)
                );
            }
            catch (const std::exception& error)
            {
                std::cerr
                    << "[API] acknowledge alarm error: "
                    << error.what()
                    << '\n';

                send_json(
                    response,
                    {{"error", "Unable to acknowledge alarm."}},
                    500
                );
            }
        }
    );


    server.Post(
        "/api/mobile-devices/push-token",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            const auto authenticated_mobile_user =
                authenticated_user(
                    request,
                    response,
                    users_,
                    jwt_
                );

            if (!authenticated_mobile_user.has_value())
            {
                return;
            }

            try
            {
                if (request.body.size() > 16384)
                {
                    send_json(
                        response,
                        {
                            {"error", "Request body is too large."}
                        },
                        413
                    );

                    return;
                }

                nlohmann::json request_body;

                try
                {
                    request_body =
                        nlohmann::json::parse(
                            request.body
                        );
                }
                catch (...)
                {
                    send_json(
                        response,
                        {
                            {"error", "Invalid JSON body."}
                        },
                        400
                    );

                    return;
                }

                if (!request_body.contains("fcm_token"))
                {
                    send_json(
                        response,
                        {
                            {"error", "FCM token is required."}
                        },
                        400
                    );

                    return;
                }

                if (!request_body["fcm_token"].is_string())
                {
                    send_json(
                        response,
                        {
                            {"error", "FCM token must be a string."}
                        },
                        400
                    );

                    return;
                }

                if (!request_body.contains("platform"))
                {
                    send_json(
                        response,
                        {
                            {"error", "Mobile platform is required."}
                        },
                        400
                    );

                    return;
                }

                if (!request_body["platform"].is_string())
                {
                    send_json(
                        response,
                        {
                            {"error", "Mobile platform must be a string."}
                        },
                        400
                    );

                    return;
                }

                const std::string firebase_cloud_messaging_token =
                    request_body["fcm_token"].get<std::string>();

                const std::string mobile_platform =
                    request_body["platform"].get<std::string>();

                if (firebase_cloud_messaging_token.empty())
                {
                    send_json(
                        response,
                        {
                            {"error", "FCM token cannot be empty."}
                        },
                        400
                    );

                    return;
                }

                if (firebase_cloud_messaging_token.size() > 8192)
                {
                    send_json(
                        response,
                        {
                            {"error", "FCM token is too long."}
                        },
                        400
                    );

                    return;
                }

                bool mobile_platform_is_supported = false;

                if (mobile_platform == "android")
                {
                    mobile_platform_is_supported = true;
                }

                if (mobile_platform == "ios")
                {
                    mobile_platform_is_supported = true;
                }

                if (!mobile_platform_is_supported)
                {
                    send_json(
                        response,
                        {
                            {"error", "Unsupported mobile platform."}
                        },
                        400
                    );

                    return;
                }

                database_.save_mobile_push_notification_token(
                    authenticated_mobile_user->id,
                    firebase_cloud_messaging_token,
                    mobile_platform
                );

                send_json(
                    response,
                    {
                        {"status", "registered"},
                        {"platform", mobile_platform}
                    }
                );
            }
            catch (const std::exception& error)
            {
                std::cerr
                    << "[API] push token registration error: "
                    << error.what()
                    << '\n';

                send_json(
                    response,
                    {
                        {"error", "Unable to register mobile device."}
                    },
                    500
                );
            }
        }
    );

    // Only the current authenticated user may revoke this token. Returning
    // the same result for an absent/foreign token prevents enumeration.
    server.Delete(
        "/api/mobile-devices/push-token",
        [this](
            const httplib::Request& request,
            httplib::Response& response
        )
        {
            const auto user = authenticated_user(
                request, response, users_, jwt_
            );
            if (!user.has_value())
                return;

            if (request.body.size() > 16384)
            {
                send_json(response, {{"error", "Request body is too large."}}, 413);
                return;
            }

            nlohmann::json body;
            try
            {
                body = nlohmann::json::parse(request.body);
            }
            catch (...)
            {
                send_json(response, {{"error", "Invalid JSON body."}}, 400);
                return;
            }

            if (!body.is_object() ||
                !body.contains("fcm_token") ||
                !body["fcm_token"].is_string())
            {
                send_json(response, {{"error", "FCM token is required."}}, 400);
                return;
            }

            const std::string token = body["fcm_token"].get<std::string>();
            if (token.empty() || token.size() > 8192)
            {
                send_json(response, {{"error", "Invalid FCM token."}}, 400);
                return;
            }

            try
            {
                database_.deactivate_mobile_push_notification_token(user->id, token);
                send_json(response, {{"status", "unregistered"}});
            }
            catch (const std::exception&)
            {
                // Do not log FCM tokens or database errors containing secrets.
                std::cerr << "[API] Could not unregister mobile push token.\n";
                send_json(response, {{"error", "Unable to unregister device."}}, 500);
            }
        }
    );

    std::cout
        << "[API] Listening on http://"
        << host
        << ":"
        << port
        << '\n';

    if (!server.listen(host, port))
    {
        std::cerr
            << "[API] Failed to start HTTP server.\n";
    }
}
