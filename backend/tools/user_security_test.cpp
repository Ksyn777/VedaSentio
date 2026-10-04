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
                "Missing environment variable: "
            ) + name
        );
    }

    return value;
}

std::string make_connection_string()
{
    return
        "host=" +
        require_env("VEDASENTIO_DB_HOST") +
        " port=" +
        require_env("VEDASENTIO_DB_PORT") +
        " dbname=" +
        require_env("VEDASENTIO_DB_NAME") +
        " user=" +
        require_env("VEDASENTIO_DB_USER") +
        " password=" +
        require_env("VEDASENTIO_DB_PASSWORD");
}

void ensure_test_home(
    const std::string& connection_string
)
{
    pqxx::connection connection(
        connection_string
    );

    pqxx::work transaction(
        connection
    );

    transaction.exec(
        R"SQL(
            INSERT INTO homes
            (
                id,
                name
            )
            VALUES
            (
                'home_001',
                'Dom testowy'
            )
            ON CONFLICT (id)
            DO NOTHING
        )SQL"
    );

    transaction.commit();
}

void verify_encrypted_at_rest(
    const std::string& connection_string,
    long long user_id
)
{
    pqxx::connection connection(
        connection_string
    );

    pqxx::read_transaction transaction(
        connection
    );

    const pqxx::result result =
        transaction.exec(
            R"SQL(
                SELECT
                    email_encrypted,
                    first_name_encrypted,
                    last_name_encrypted,
                    phone_encrypted,
                    password_hash
                FROM users
                WHERE id = $1
            )SQL",
            pqxx::params{
                user_id
            }
        );

    if (result.empty())
    {
        throw std::runtime_error(
            "Test user disappeared."
        );
    }

    const auto& row = result[0];

    if (
        row["email_encrypted"]
            .as<std::string>()
            .find("@example.invalid") !=
        std::string::npos
    )
    {
        throw std::runtime_error(
            "E-mail appears to be stored in plaintext."
        );
    }

    if (
        row["first_name_encrypted"]
            .as<std::string>() ==
        "Jan"
    )
    {
        throw std::runtime_error(
            "First name is stored in plaintext."
        );
    }

    const std::string password_hash =
        row["password_hash"]
            .as<std::string>();

    if (
        password_hash.rfind(
            "$argon2id$",
            0
        ) != 0
    )
    {
        throw std::runtime_error(
            "Password hash is not Argon2id."
        );
    }
}

void delete_test_user(
    const std::string& connection_string,
    long long user_id
)
{
    pqxx::connection connection(
        connection_string
    );

    pqxx::work transaction(
        connection
    );

    transaction.exec(
        "DELETE FROM users "
        "WHERE id = $1",
        pqxx::params{
            user_id
        }
    );

    transaction.commit();
}
}

int main()
{
    long long created_user_id = 0;

    try
    {
        const std::string connection_string =
            make_connection_string();

        ensure_test_home(
            connection_string
        );

        CryptoService crypto(
            require_env(
                "VEDASENTIO_DATA_ENCRYPTION_KEY_B64"
            ),
            require_env(
                "VEDASENTIO_LOOKUP_HMAC_KEY_B64"
            )
        );

        UserRepository users(
            connection_string,
            crypto
        );

        const auto stamp =
            std::chrono::system_clock::now()
                .time_since_epoch()
                .count();

        CreateUserInput input;

        input.email =
            "security_test_" +
            std::to_string(stamp) +
            "@example.invalid";

        input.password =
            "Safe-Test-Password-2026!";

        input.first_name =
            "Jan";

        input.last_name =
            "Kowalski";

        input.phone =
            "+48000000000";

        const User created =
            users.create_user(input);

        created_user_id =
            created.id;

        std::cout
            << "[USER] User created.\n";

        verify_encrypted_at_rest(
            connection_string,
            created.id
        );

        std::cout
            << "[USER] PII encrypted at rest OK.\n";

        const auto loaded =
            users.get_by_id(
                created.id
            );

        if (
            !loaded.has_value() ||
            loaded->email !=
                UserRepository::normalize_email(
                    input.email
                ) ||
            loaded->first_name !=
                input.first_name ||
            loaded->last_name !=
                input.last_name ||
            loaded->phone !=
                input.phone
        )
        {
            throw std::runtime_error(
                "Encrypted user round-trip failed."
            );
        }

        std::cout
            << "[USER] Encrypted user round-trip OK.\n";

        const auto valid_login =
            users.authenticate(
                input.email,
                input.password
            );

        if (!valid_login.has_value())
        {
            throw std::runtime_error(
                "Correct password was rejected."
            );
        }

        std::cout
            << "[USER] Argon2id password verification OK.\n";

        const auto invalid_login =
            users.authenticate(
                input.email,
                "Wrong-Test-Password-2026!"
            );

        if (invalid_login.has_value())
        {
            throw std::runtime_error(
                "Wrong password was accepted."
            );
        }

        std::cout
            << "[USER] Wrong password rejected OK.\n";

        users.grant_home_access(
            created.id,
            "home_001",
            "caregiver"
        );

        if (
            !users.has_home_access(
                created.id,
                "home_001"
            )
        )
        {
            throw std::runtime_error(
                "Home authorization mapping failed."
            );
        }

        std::cout
            << "[USER] user_homes authorization mapping OK.\n";

        delete_test_user(
            connection_string,
            created.id
        );

        created_user_id = 0;

        std::cout
            << "[USER] Test user cleaned up.\n";

        std::cout
            << "[USER] ALL SECURITY TESTS OK.\n";

        return 0;
    }
    catch (const std::exception& error)
    {
        std::cerr
            << "[USER] Error: "
            << error.what()
            << '\n';

        if (created_user_id != 0)
        {
            try
            {
                delete_test_user(
                    make_connection_string(),
                    created_user_id
                );
            }
            catch (...)
            {
            }
        }

        return 1;
    }
}
