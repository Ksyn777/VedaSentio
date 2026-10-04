#pragma once

#include <string>

class PasswordHasher
{
public:
    static std::string hash_password(
        const std::string& password
    );

    static bool verify_password(
        const std::string& password,
        const std::string& encoded_hash
    );

private:
    static void ensure_sodium();
};
