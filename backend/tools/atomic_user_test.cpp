#include "../src/security/CryptoService.h"
#include "../src/users/UserRepository.h"

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>

#include <pqxx/pqxx>

namespace
{
std::string require_env(const char* name)
{
    const char* value = std::getenv(name);
    if (value == nullptr || *value == '\0')
        throw std::runtime_error(std::string("Missing environment variable: ") + name);
    return value;
}

std::string conninfo()
{
    return
        "host=" + require_env("VEDASENTIO_DB_HOST") +
        " port=" + require_env("VEDASENTIO_DB_PORT") +
        " dbname=" + require_env("VEDASENTIO_DB_NAME") +
        " user=" + require_env("VEDASENTIO_DB_USER") +
        " password=" + require_env("VEDASENTIO_DB_PASSWORD");
}

long long count_user(const std::string& c, const std::string& lookup)
{
    pqxx::connection connection(c);
    pqxx::read_transaction tx(connection);

    const pqxx::result result = tx.exec(
        "SELECT COUNT(*) AS count FROM users WHERE email_lookup_hmac = $1",
        pqxx::params{lookup}
    );

    return result[0]["count"].as<long long>();
}
}

int main()
{
    try
    {
        const std::string c = conninfo();

        CryptoService crypto(
            require_env("VEDASENTIO_DATA_ENCRYPTION_KEY_B64"),
            require_env("VEDASENTIO_LOOKUP_HMAC_KEY_B64")
        );

        UserRepository users(c, crypto);

        const auto stamp =
            std::chrono::system_clock::now().time_since_epoch().count();

        CreateUserWithHomeInput input;
        input.user.email = "atomic_test_" + std::to_string(stamp) + "@example.invalid";
        input.user.password = "Atomic-Test-Password-2026!";
        input.user.first_name = "Atomic";
        input.user.last_name = "Rollback";
        input.user.phone = "+48000000000";
        input.home_id = "home_that_does_not_exist";
        input.role = "owner";

        const std::string lookup =
            crypto.lookup_hmac_hex(
                UserRepository::normalize_email(input.user.email)
            );

        bool rejected = false;

        try
        {
            static_cast<void>(users.create_user_with_home_access(input));
        }
        catch (const std::exception&)
        {
            rejected = true;
        }

        if (!rejected)
            throw std::runtime_error("Invalid home was unexpectedly accepted.");

        if (count_user(c, lookup) != 0)
            throw std::runtime_error("Rollback failed: partial user remains in database.");

        std::cout << "[ATOMIC] Invalid home rejected OK.\n";
        std::cout << "[ATOMIC] No partial user remained in database.\n";
        std::cout << "[ATOMIC] Transaction rollback OK.\n";

        return 0;
    }
    catch (const std::exception& error)
    {
        std::cerr << "[ATOMIC] Error: " << error.what() << '\n';
        return 1;
    }
}
