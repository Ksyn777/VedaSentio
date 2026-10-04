#include "UserRepository.h"
#include "../auth/PasswordHasher.h"

#include <algorithm>
#include <cctype>
#include <stdexcept>
#include <utility>
#include <pqxx/pqxx>

namespace
{
std::string trim_copy(const std::string& input)
{
    auto first = std::find_if_not(input.begin(), input.end(), [](unsigned char c){ return std::isspace(c) != 0; });
    auto last = std::find_if_not(input.rbegin(), input.rend(), [](unsigned char c){ return std::isspace(c) != 0; }).base();
    if (first >= last) return {};
    return std::string(first, last);
}

void validate_role(const std::string& role)
{
    if (role != "owner" && role != "caregiver" && role != "viewer")
        throw std::runtime_error("Unsupported home role.");
}

void ensure_home_exists(pqxx::work& tx, const std::string& home_id)
{
    const pqxx::result result = tx.exec(
        "SELECT 1 FROM homes WHERE id = $1 LIMIT 1",
        pqxx::params{home_id}
    );

    if (result.empty())
        throw std::runtime_error("Home '" + home_id + "' does not exist.");
}
}

UserRepository::UserRepository(std::string connection_string, const CryptoService& crypto)
    : connection_string_(std::move(connection_string)), crypto_(crypto)
{
}

std::string UserRepository::normalize_email(const std::string& email)
{
    std::string normalized = trim_copy(email);

    std::transform(
        normalized.begin(),
        normalized.end(),
        normalized.begin(),
        [](unsigned char c){ return static_cast<char>(std::tolower(c)); }
    );

    if (normalized.empty() || normalized.size() > 320 || normalized.find('@') == std::string::npos)
        throw std::runtime_error("Invalid e-mail address.");

    return normalized;
}

User UserRepository::create_user(const CreateUserInput& input) const
{
    const std::string normalized_email = normalize_email(input.email);
    const std::string lookup_hmac = crypto_.lookup_hmac_hex(normalized_email);
    const std::string password_hash = PasswordHasher::hash_password(input.password);

    const std::string email_encrypted = crypto_.encrypt_field(normalized_email, "users.email");
    const std::string first_name_encrypted = crypto_.encrypt_field(input.first_name, "users.first_name");
    const std::string last_name_encrypted = crypto_.encrypt_field(input.last_name, "users.last_name");
    const std::string phone_encrypted = crypto_.encrypt_field(input.phone, "users.phone");

    pqxx::connection connection(connection_string_);
    pqxx::work tx(connection);

    const pqxx::result existing = tx.exec(
        "SELECT 1 FROM users WHERE email_lookup_hmac = $1 LIMIT 1",
        pqxx::params{lookup_hmac}
    );

    if (!existing.empty())
        throw std::runtime_error("User with this e-mail already exists.");

    const pqxx::result result = tx.exec(
        R"SQL(
            INSERT INTO users
            (
                email_encrypted,
                email_lookup_hmac,
                password_hash,
                first_name_encrypted,
                last_name_encrypted,
                phone_encrypted
            )
            VALUES ($1,$2,$3,$4,$5,$6)
            RETURNING id, created_at::text AS created_at
        )SQL",
        pqxx::params{
            email_encrypted,
            lookup_hmac,
            password_hash,
            first_name_encrypted,
            last_name_encrypted,
            phone_encrypted
        }
    );

    tx.commit();

    User user;
    user.id = result[0]["id"].as<long long>();
    user.email = normalized_email;
    user.first_name = input.first_name;
    user.last_name = input.last_name;
    user.phone = input.phone;
    user.is_active = true;
    user.created_at = result[0]["created_at"].as<std::string>();
    return user;
}

User UserRepository::create_user_with_home_access(const CreateUserWithHomeInput& input) const
{
    validate_role(input.role);

    const std::string normalized_email = normalize_email(input.user.email);
    const std::string lookup_hmac = crypto_.lookup_hmac_hex(normalized_email);
    const std::string password_hash = PasswordHasher::hash_password(input.user.password);

    const std::string email_encrypted = crypto_.encrypt_field(normalized_email, "users.email");
    const std::string first_name_encrypted = crypto_.encrypt_field(input.user.first_name, "users.first_name");
    const std::string last_name_encrypted = crypto_.encrypt_field(input.user.last_name, "users.last_name");
    const std::string phone_encrypted = crypto_.encrypt_field(input.user.phone, "users.phone");

    pqxx::connection connection(connection_string_);
    pqxx::work tx(connection);

    ensure_home_exists(tx, input.home_id);

    const pqxx::result existing = tx.exec(
        "SELECT 1 FROM users WHERE email_lookup_hmac = $1 LIMIT 1",
        pqxx::params{lookup_hmac}
    );

    if (!existing.empty())
        throw std::runtime_error("User with this e-mail already exists.");

    const pqxx::result result = tx.exec(
        R"SQL(
            INSERT INTO users
            (
                email_encrypted,
                email_lookup_hmac,
                password_hash,
                first_name_encrypted,
                last_name_encrypted,
                phone_encrypted
            )
            VALUES ($1,$2,$3,$4,$5,$6)
            RETURNING id, created_at::text AS created_at
        )SQL",
        pqxx::params{
            email_encrypted,
            lookup_hmac,
            password_hash,
            first_name_encrypted,
            last_name_encrypted,
            phone_encrypted
        }
    );

    const long long user_id = result[0]["id"].as<long long>();

    tx.exec(
        R"SQL(
            INSERT INTO user_homes(user_id, home_id, role)
            VALUES ($1,$2,$3)
        )SQL",
        pqxx::params{
            user_id,
            input.home_id,
            input.role
        }
    );

    tx.commit();

    User user;
    user.id = user_id;
    user.email = normalized_email;
    user.first_name = input.user.first_name;
    user.last_name = input.user.last_name;
    user.phone = input.user.phone;
    user.is_active = true;
    user.created_at = result[0]["created_at"].as<std::string>();
    return user;
}

std::optional<User> UserRepository::get_by_id(long long user_id) const
{
    pqxx::connection connection(connection_string_);
    pqxx::read_transaction tx(connection);

    const pqxx::result result = tx.exec(
        R"SQL(
            SELECT id, email_encrypted, first_name_encrypted, last_name_encrypted,
                   phone_encrypted, is_active, created_at::text AS created_at
            FROM users
            WHERE id = $1
            LIMIT 1
        )SQL",
        pqxx::params{user_id}
    );

    if (result.empty()) return std::nullopt;
    return decrypt_user_row(result[0]);
}

std::optional<User> UserRepository::authenticate(const std::string& email, const std::string& password) const
{
    const std::string normalized_email = normalize_email(email);
    const std::string lookup_hmac = crypto_.lookup_hmac_hex(normalized_email);

    pqxx::connection connection(connection_string_);
    pqxx::read_transaction tx(connection);

    const pqxx::result result = tx.exec(
        R"SQL(
            SELECT id, email_encrypted, password_hash, first_name_encrypted,
                   last_name_encrypted, phone_encrypted, is_active,
                   created_at::text AS created_at
            FROM users
            WHERE email_lookup_hmac = $1
            LIMIT 1
        )SQL",
        pqxx::params{lookup_hmac}
    );

    if (result.empty())
    {
        static_cast<void>(
            PasswordHasher::hash_password(
                password.size() >= 10 ? password : "invalid-password-placeholder"
            )
        );
        return std::nullopt;
    }

    const auto& row = result[0];

    if (!row["is_active"].as<bool>())
        return std::nullopt;

    const std::string password_hash = row["password_hash"].as<std::string>();

    if (!PasswordHasher::verify_password(password, password_hash))
        return std::nullopt;

    return decrypt_user_row(row);
}

void UserRepository::grant_home_access(long long user_id, const std::string& home_id, const std::string& role) const
{
    validate_role(role);

    pqxx::connection connection(connection_string_);
    pqxx::work tx(connection);

    ensure_home_exists(tx, home_id);

    tx.exec(
        R"SQL(
            INSERT INTO user_homes(user_id, home_id, role)
            VALUES ($1,$2,$3)
            ON CONFLICT (user_id, home_id)
            DO UPDATE SET role = EXCLUDED.role
        )SQL",
        pqxx::params{user_id, home_id, role}
    );

    tx.commit();
}

bool UserRepository::has_home_access(long long user_id, const std::string& home_id) const
{
    pqxx::connection connection(connection_string_);
    pqxx::read_transaction tx(connection);

    const pqxx::result result = tx.exec(
        R"SQL(
            SELECT EXISTS
            (
                SELECT 1
                FROM user_homes
                WHERE user_id = $1 AND home_id = $2
            ) AS has_access
        )SQL",
        pqxx::params{user_id, home_id}
    );

    return result[0]["has_access"].as<bool>();
}

std::vector<HomeMembership> UserRepository::get_home_memberships(long long user_id) const
{
    pqxx::connection connection(connection_string_);
    pqxx::read_transaction tx(connection);

    const pqxx::result result = tx.exec(
        "SELECT home_id, role FROM user_homes WHERE user_id = $1 ORDER BY home_id",
        pqxx::params{user_id}
    );

    std::vector<HomeMembership> memberships;
    memberships.reserve(result.size());

    for (const auto& row : result)
    {
        HomeMembership membership;
        membership.home_id = row["home_id"].as<std::string>();
        membership.role = row["role"].as<std::string>();
        memberships.push_back(std::move(membership));
    }

    return memberships;
}
