#pragma once

#include <array>
#include <string>

#include <sodium.h>

struct JwtClaims
{
    long long user_id = 0;
    long long issued_at = 0;
    long long expires_at = 0;
    std::string token_id;
};

class JwtService
{
public:
    explicit JwtService(
        const std::string& signing_key_b64
    );

    ~JwtService();

    JwtService(const JwtService&) = delete;
    JwtService& operator=(const JwtService&) = delete;
    JwtService(JwtService&&) = delete;
    JwtService& operator=(JwtService&&) = delete;

    std::string create_access_token(
        long long user_id,
        long long lifetime_seconds = 3600
    ) const;

    JwtClaims verify_access_token(
        const std::string& token
    ) const;

private:
    static std::array<
        unsigned char,
        crypto_auth_hmacsha256_KEYBYTES
    > decode_key(
        const std::string& encoded
    );

    static std::string base64url_encode(
        const unsigned char* data,
        std::size_t size
    );

    static std::string base64url_encode(
        const std::string& value
    );

    static std::string base64url_decode(
        const std::string& encoded
    );

    std::string sign(
        const std::string& signing_input
    ) const;

    static long long unix_time_now();

    std::array<
        unsigned char,
        crypto_auth_hmacsha256_KEYBYTES
    > signing_key_{};
};
