// CI-only API fixture using real UserRepository, JWT, Database and AlarmRepository.
// Starts a loopback HTTP listener in a disposable PostgreSQL database.
#include "../src/api/ApiServer.h"
#include "../src/auth/JwtService.h"
#include "../src/database/Database.h"
#include "../src/alarms/AlarmRepository.h"
#include "../src/users/UserRepository.h"
#include "../src/security/CryptoService.h"

#include <pqxx/pqxx>

#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>
#include <utility>

namespace {
std::string required(const char* name) {
    const char* value = std::getenv(name);
    if (!value || !*value)
        throw std::runtime_error(std::string("Missing CI environment: ") + name);
    return value;
}

std::string quote(const std::string& value) {
    std::string result = "'";
    for (char ch : value) {
        if (ch == '\'' || ch == '\\') result += '\\';
        result += ch;
    }
    return result + "'";
}

std::string conninfo() {
    const std::string host = required("VEDASENTIO_DB_HOST");
    const std::string name = required("VEDASENTIO_DB_NAME");
    if (host != "127.0.0.1" || name != "vedasentio_api_ci") {
        throw std::runtime_error("Refusing to use a non-local or non-test database.");
    }
    return "host=" + quote(host) +
           " port=" + quote(required("VEDASENTIO_DB_PORT")) +
           " dbname=" + quote(name) +
           " user=" + quote(required("VEDASENTIO_DB_USER")) +
           " password=" + quote(required("VEDASENTIO_DB_PASSWORD"));
}

void seed_homes(const std::string& connection_string) {
    pqxx::connection conn(connection_string);
    pqxx::work tx(conn);
    tx.exec("INSERT INTO homes(id,name) VALUES('api_home_ci','Owned Test Home'),"
            "('api_other_ci','Other Test Home')");
    tx.exec("INSERT INTO devices(home_id,id,device_type,name) VALUES "
            "('api_home_ci','sos_one','sos_button','SOS One'), "
            "('api_home_ci','sos_two','sos_button','SOS Two'), "
            "('api_other_ci','foreign_door','door_contact','Foreign Door')");
    tx.commit();
}

void seed_users(UserRepository& users) {
    const std::string password = required("VEDASENTIO_API_TEST_PASSWORD");
    const auto make_user = [&](const std::string& email) {
        CreateUserInput input;
        input.email = email;
        input.password = password;
        input.first_name = "CI";
        input.last_name = "Test";
        input.phone = "+48000000000";
        return users.create_user(input);
    };

    auto owner = make_user("api-owner@example.invalid");
    auto caregiver = make_user("api-caregiver@example.invalid");
    auto viewer = make_user("api-viewer@example.invalid");
    auto outsider = make_user("api-outsider@example.invalid");

    users.grant_home_access(owner.id, "api_home_ci", "owner");
    users.grant_home_access(caregiver.id, "api_home_ci", "caregiver");
    users.grant_home_access(viewer.id, "api_home_ci", "viewer");
    users.grant_home_access(outsider.id, "api_other_ci", "owner");
}

void seed_alarms(Database& db, AlarmRepository& alarms) {
    for (const char* device_id : {"sos_one", "sos_two"}) {
        SensorEvent event;
        event.home_id = "api_home_ci";
        event.device_id = device_id;
        event.topic = "vedasentio/api_home_ci/" + event.device_id + "/event";
        event.event_type = "sos_pressed";
        event.value_json = "true";
        event.device_timestamp = "2026-11-22T10:00:00Z";
        event.raw_payload = R"({"timestamp":"2026-11-22T10:00:00Z","event_type":"sos_pressed","value":true})";
        const auto id = db.save_event(event);
        if (!alarms.process_event(event, id).has_value())
            throw std::runtime_error("Could not create CI alarm fixture.");
    }
}

int port() {
    const std::string number = required("VEDASENTIO_API_TEST_PORT");
    try {
        const int p = std::stoi(number);
        if (p < 1024 || p > 65535)
            throw std::runtime_error("Port outside allowed range");
        return p;
    } catch (...) {
        throw std::runtime_error("Invalid CI API port.");
    }
}
}

int main() {
    std::cout << std::unitbuf;
    try {
        const std::string connection_string = conninfo();
        const int listen_port = port();
        CryptoService crypto(
            required("VEDASENTIO_DATA_ENCRYPTION_KEY_B64"),
            required("VEDASENTIO_LOOKUP_HMAC_KEY_B64"));
        JwtService jwt(required("VEDASENTIO_JWT_SIGNING_KEY_B64"));
        Database db(connection_string);
        UserRepository users(connection_string, crypto);
        AlarmRepository alarms(connection_string);
        db.test_connection();
        seed_homes(connection_string);
        seed_users(users);
        seed_alarms(db, alarms);

        ApiServer server(db, users, jwt, alarms);
        std::cout << "[API-CI] FIXTURES_READY\n";
        server.start("127.0.0.1", listen_port);
        std::cerr << "[API-CI] HTTP server exited unexpectedly.\n";
        return 1;
    } catch (const std::exception& error) {
        std::cerr << "[API-CI] FAILED: " << error.what() << '\n';
        return 1;
    }
}
