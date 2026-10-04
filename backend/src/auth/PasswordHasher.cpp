#include "PasswordHasher.h"

#include <array>
#include <stdexcept>

#include <sodium.h>

void PasswordHasher::ensure_sodium()
{
    if (sodium_init() < 0)
    {
        throw std::runtime_error(
            "Unable to initialize libsodium."
        );
    }
}

std::string PasswordHasher::hash_password(
    const std::string& password
)
{
    ensure_sodium();

    if (password.size() < 10)
    {
        throw std::runtime_error(
            "Password must contain at least 10 characters."
        );
    }

    std::array<char, crypto_pwhash_STRBYTES> hash{};

    const int result =
        crypto_pwhash_str_alg(
            hash.data(),
            password.c_str(),
            static_cast<unsigned long long>(
                password.size()
            ),
            crypto_pwhash_OPSLIMIT_INTERACTIVE,
            crypto_pwhash_MEMLIMIT_INTERACTIVE,
            crypto_pwhash_ALG_ARGON2ID13
        );

    if (result != 0)
    {
        throw std::runtime_error(
            "Unable to hash password."
        );
    }

    return std::string(
        hash.data()
    );
}

bool PasswordHasher::verify_password(
    const std::string& password,
    const std::string& encoded_hash
)
{
    ensure_sodium();

    return crypto_pwhash_str_verify(
        encoded_hash.c_str(),
        password.c_str(),
        static_cast<unsigned long long>(
            password.size()
        )
    ) == 0;
}
