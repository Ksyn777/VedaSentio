// CI-only PostgreSQL + real HTTP API fixture for mobile push token revocation.
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

namespace {
std::string required(const char* key) {
    const char* v = std::getenv(key);
    if (!v || !*v) throw std::runtime_error("Missing CI configuration.");
    return v;
}

std::string database_connection() {
    const auto host = required("VEDASENTIO_DB_HOST");
    const auto db = required("VEDASENTIO_DB_NAME");
    if (host != "127.0.0.1" || db != "vedasentio_push_revoke_ci")
        throw std::runtime_error("Refusing non-test database.");

    // All CI connection fields are controlled literals, not production input.
    return "host=" + host +
           " port=" + required("VEDASENTIO_DB_PORT") +
           " dbname=" + db +
           " user=" + required("VEDASENTIO_DB_USER") +
           " password=" + required("VEDASENTIO_DB_PASSWORD");
}

void seed(const std::string& connection, UserRepository& users) {
    pqxx::connection conn(connection);
    {
        pqxx::work tx(conn);
        tx.exec("INSERT INTO homes(id,name) VALUES "
                "('ci_push_home_a','Owned CI A'),('ci_push_home_b','Owned CI B')");
        tx.commit();
    }

    CreateUserInput input;
    input.password = required("VEDASENTIO_API_TEST_PASSWORD");
    input.first_name = "CI";
    input.last_name = "Test";
    input.phone = "+48000000000";

    input.email = "push-owner-a@example.invalid";
    const auto first = users.create_user(input);
    users.grant_home_access(first.id, "ci_push_home_a", "owner");

    input.email = "push-owner-b@example.invalid";
    const auto second = users.create_user(input);
    users.grant_home_access(second.id, "ci_push_home_b", "owner");
}
}

int main() {
    std::cout << std::unitbuf;
    try {
        const auto conn = database_connection();
        CryptoService crypto(
            required("VEDASENTIO_DATA_ENCRYPTION_KEY_B64"),
            required("VEDASENTIO_LOOKUP_HMAC_KEY_B64")
        );
        JwtService jwt(required("VEDASENTIO_JWT_SIGNING_KEY_B64"));
        Database db(conn);
        UserRepository users(conn, crypto);
        AlarmRepository alarms(conn);
        db.test_connection();
        seed(conn, users);

        ApiServer api(db, users, jwt, alarms);
        std::cout << "[PUSH-REVOKE-CI] FIXTURES_READY\n";
        api.start("127.0.0.1", 28911);
        return 1;
    } catch (const std::exception& error) {
        std::cerr << "[PUSH-REVOKE-CI] Setup failure: " << error.what() << '\n';
        return 1;
    }
}
