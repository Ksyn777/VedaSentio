#include "ApiServer.h"
#include "../database/Database.h"
#include <httplib.h>
#include <nlohmann/json.hpp>
#include <iostream>
#include <string>

namespace {
void send_json(httplib::Response& response, const nlohmann::json& body, int status = 200)
{
    response.status = status;
    response.set_content(body.dump(2), "application/json; charset=utf-8");
}

nlohmann::json event_to_json(const EventRecord& event)
{
    nlohmann::json value;
    try { value = nlohmann::json::parse(event.value_json); }
    catch (...) { value = event.value_json; }

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
}

ApiServer::ApiServer(Database& database) : database_(database) {}

void ApiServer::start(const std::string& host, int port)
{
    httplib::Server server;

    server.Get("/api/health", [](const httplib::Request&, httplib::Response& response) {
        send_json(response, {{"status", "ok"}, {"service", "vedasentio-backend"}});
    });

    server.Get("/api/homes", [this](const httplib::Request&, httplib::Response& response) {
        try {
            nlohmann::json body = nlohmann::json::array();
            for (const auto& home : database_.get_homes()) {
                body.push_back({{"id", home.id}, {"name", home.name}, {"created_at", home.created_at}});
            }
            send_json(response, body);
        } catch (const std::exception& error) {
            send_json(response, {{"error", error.what()}}, 500);
        }
    });

    server.Get(R"(/api/homes/([^/]+)/devices)",
        [this](const httplib::Request& request, httplib::Response& response) {
            try {
                const std::string home_id = request.matches[1];
                nlohmann::json body = nlohmann::json::array();
                for (const auto& device : database_.get_devices(home_id)) {
                    body.push_back({
                        {"home_id", device.home_id},
                        {"id", device.id},
                        {"device_type", device.device_type},
                        {"name", device.name},
                        {"is_active", device.is_active},
                        {"created_at", device.created_at}
                    });
                }
                send_json(response, body);
            } catch (const std::exception& error) {
                send_json(response, {{"error", error.what()}}, 500);
            }
        });

    server.Get(R"(/api/homes/([^/]+)/events)",
        [this](const httplib::Request& request, httplib::Response& response) {
            try {
                const std::string home_id = request.matches[1];
                int limit = 100;
                if (request.has_param("limit")) {
                    try { limit = std::stoi(request.get_param_value("limit")); }
                    catch (...) {
                        send_json(response, {{"error", "Invalid limit parameter."}}, 400);
                        return;
                    }
                }
                nlohmann::json body = nlohmann::json::array();
                for (const auto& event : database_.get_events(home_id, limit)) {
                    body.push_back(event_to_json(event));
                }
                send_json(response, body);
            } catch (const std::exception& error) {
                send_json(response, {{"error", error.what()}}, 500);
            }
        });

    server.Get(R"(/api/homes/([^/]+)/devices/([^/]+)/latest)",
        [this](const httplib::Request& request, httplib::Response& response) {
            try {
                const std::string home_id = request.matches[1];
                const std::string device_id = request.matches[2];
                const auto event = database_.get_latest_event(home_id, device_id);
                if (!event.has_value()) {
                    send_json(response, {{"error", "No event found."}}, 404);
                    return;
                }
                send_json(response, event_to_json(*event));
            } catch (const std::exception& error) {
                send_json(response, {{"error", error.what()}}, 500);
            }
        });

    std::cout << "[API] Listening on http://" << host << ":" << port << '\n';

    if (!server.listen(host, port)) {
        std::cerr << "[API] Failed to start HTTP server.\n";
    }
}
