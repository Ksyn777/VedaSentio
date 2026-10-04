#pragma once

#include "../model/User.h"
#include "../security/CryptoService.h"

#include <optional>
#include <string>

class UserRepository
{
public:
    UserRepository(
        std::string connection_string,
        const CryptoService& crypto
    );

    User create_user(
        const CreateUserInput& input
    ) const;

    std::optional<User> get_by_id(
        long long user_id
    ) const;

    std::optional<User> authenticate(
        const std::string& email,
        const std::string& password
    ) const;

    void grant_home_access(
        long long user_id,
        const std::string& home_id,
        const std::string& role
    ) const;

    bool has_home_access(
        long long user_id,
        const std::string& home_id
    ) const;

    static std::string normalize_email(
        const std::string& email
    );

private:
    User decrypt_user_row(
        const auto& row
    ) const
    {
        User user;

        user.id =
            row["id"].template as<long long>();

        user.email =
            crypto_.decrypt_field(
                row["email_encrypted"]
                    .template as<std::string>(),
                "users.email"
            );

        user.first_name =
            crypto_.decrypt_field(
                row["first_name_encrypted"]
                    .template as<std::string>(),
                "users.first_name"
            );

        user.last_name =
            crypto_.decrypt_field(
                row["last_name_encrypted"]
                    .template as<std::string>(),
                "users.last_name"
            );

        user.phone =
            crypto_.decrypt_field(
                row["phone_encrypted"]
                    .template as<std::string>(),
                "users.phone"
            );

        user.is_active =
            row["is_active"]
                .template as<bool>();

        user.created_at =
            row["created_at"]
                .template as<std::string>();

        return user;
    }

    std::string connection_string_;
    const CryptoService& crypto_;
};
