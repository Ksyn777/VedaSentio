#include "../src/security/CryptoService.h"
#include "../src/users/UserRepository.h"

#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>

namespace
{
std::string require_env(const char* name)
{
    const char* value = std::getenv(name);

    if (value == nullptr || *value == '\0')
        throw std::runtime_error(std::string("Missing environment variable: ") + name);

    return value;
}

std::string quote_conninfo_value(const std::string& value)
{
    std::string result;
    result.reserve(value.size() + 2);
    result.push_back('\'');

    for (char c : value)
    {
        if (c == '\\' || c == '\'') result.push_back('\\');
        result.push_back(c);
    }

    result.push_back('\'');
    return result;
}

std::string build_database_connection_string()
{
    return
        "host=" + quote_conninfo_value(require_env("VEDASENTIO_DB_HOST")) +
        " port=" + quote_conninfo_value(require_env("VEDASENTIO_DB_PORT")) +
        " dbname=" + quote_conninfo_value(require_env("VEDASENTIO_DB_NAME")) +
        " user=" + quote_conninfo_value(require_env("VEDASENTIO_DB_USER")) +
        " password=" + quote_conninfo_value(require_env("VEDASENTIO_DB_PASSWORD"));
}
}

int main()
{
    try
    {
        CryptoService crypto(
            require_env("VEDASENTIO_DATA_ENCRYPTION_KEY_B64"),
            require_env("VEDASENTIO_LOOKUP_HMAC_KEY_B64")
        );

        UserRepository users(
            build_database_connection_string(),
            crypto
        );

        CreateUserWithHomeInput input;
        input.user.email = require_env("VEDASENTIO_NEW_USER_EMAIL");
        input.user.password = require_env("VEDASENTIO_NEW_USER_PASSWORD");
        input.user.first_name = require_env("VEDASENTIO_NEW_USER_FIRST_NAME");
        input.user.last_name = require_env("VEDASENTIO_NEW_USER_LAST_NAME");
        input.user.phone = require_env("VEDASENTIO_NEW_USER_PHONE");
        input.home_id = require_env("VEDASENTIO_NEW_USER_HOME_ID");
        input.role = require_env("VEDASENTIO_NEW_USER_ROLE");

        const User user = users.create_user_with_home_access(input);

        std::cout << "[DEV-USER] User and home access created atomically.\n";
        std::cout << "[DEV-USER] id=" << user.id << '\n';
        std::cout << "[DEV-USER] home_id=" << input.home_id << '\n';
        std::cout << "[DEV-USER] role=" << input.role << '\n';

        return 0;
    }
    catch (const std::exception& error)
    {
        std::cerr << "[DEV-USER] Error: " << error.what() << '\n';
        std::cerr << "[DEV-USER] Transaction rolled back. No partial user should remain.\n";
        return 1;
    }
}
