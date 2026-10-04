#include "JwtService.h"

#include <array>
#include <chrono>
#include <stdexcept>
#include <vector>

#include <nlohmann/json.hpp>

namespace
{
constexpr const char* ISSUER =
    "vedasentio-backend";

constexpr const char* AUDIENCE =
    "vedasentio-client";

constexpr long long CLOCK_SKEW_SECONDS = 60;

std::array<std::string, 3> split_token(
    const std::string& token
)
{
    std::array<std::string, 3> parts;

    const std::size_t first_dot =
        token.find('.');

    if (first_dot == std::string::npos)
    {
        throw std::runtime_error(
            "Invalid JWT format."
        );
    }

    const std::size_t second_dot =
        token.find(
            '.',
            first_dot + 1
        );

    if (
        second_dot == std::string::npos ||
        token.find(
            '.',
            second_dot + 1
        ) != std::string::npos
    )
    {
        throw std::runtime_error(
            "Invalid JWT format."
        );
    }

    parts[0] =
        token.substr(
            0,
            first_dot
        );

    parts[1] =
        token.substr(
            first_dot + 1,
            second_dot - first_dot - 1
        );

    parts[2] =
        token.substr(
            second_dot + 1
        );

    if (
        parts[0].empty() ||
        parts[1].empty() ||
        parts[2].empty()
    )
    {
        throw std::runtime_error(
            "Invalid JWT format."
        );
    }

    return parts;
}

long long parse_positive_user_id(
    const nlohmann::json& payload
)
{
    if (
        !payload.contains("sub") ||
        !payload["sub"].is_string()
    )
    {
        throw std::runtime_error(
            "JWT subject is missing."
        );
    }

    const std::string subject =
        payload["sub"].get<std::string>();

    std::size_t processed = 0;
    long long user_id = 0;

    try
    {
        user_id =
            std::stoll(
                subject,
                &processed
            );
    }
    catch (...)
    {
        throw std::runtime_error(
            "JWT subject is invalid."
        );
    }

    if (
        processed != subject.size() ||
        user_id <= 0
    )
    {
        throw std::runtime_error(
            "JWT subject is invalid."
        );
    }

    return user_id;
}
}

JwtService::JwtService(
    const std::string& signing_key_b64
)
{
    if (sodium_init() < 0)
    {
        throw std::runtime_error(
            "Unable to initialize libsodium."
        );
    }

    signing_key_ =
        decode_key(
            signing_key_b64
        );
}

JwtService::~JwtService()
{
    sodium_memzero(
        signing_key_.data(),
        signing_key_.size()
    );
}

std::array<
    unsigned char,
    crypto_auth_hmacsha256_KEYBYTES
>
JwtService::decode_key(
    const std::string& encoded
)
{
    std::array<
        unsigned char,
        crypto_auth_hmacsha256_KEYBYTES
    > key{};

    std::size_t decoded_size = 0;

    const int result =
        sodium_base642bin(
            key.data(),
            key.size(),
            encoded.c_str(),
            encoded.size(),
            nullptr,
            &decoded_size,
            nullptr,
            sodium_base64_VARIANT_ORIGINAL
        );

    if (
        result != 0 ||
        decoded_size != key.size()
    )
    {
        sodium_memzero(
            key.data(),
            key.size()
        );

        throw std::runtime_error(
            "VEDASENTIO_JWT_SIGNING_KEY_B64 "
            "must be a Base64 encoded 32-byte key."
        );
    }

    return key;
}

std::string JwtService::base64url_encode(
    const unsigned char* data,
    std::size_t size
)
{
    const std::size_t encoded_size =
        sodium_base64_ENCODED_LEN(
            size,
            sodium_base64_VARIANT_URLSAFE_NO_PADDING
        );

    std::string encoded(
        encoded_size,
        '\0'
    );

    sodium_bin2base64(
        encoded.data(),
        encoded.size(),
        data,
        size,
        sodium_base64_VARIANT_URLSAFE_NO_PADDING
    );

    if (
        !encoded.empty() &&
        encoded.back() == '\0'
    )
    {
        encoded.pop_back();
    }

    return encoded;
}

std::string JwtService::base64url_encode(
    const std::string& value
)
{
    return base64url_encode(
        reinterpret_cast<
            const unsigned char*
        >(
            value.data()
        ),
        value.size()
    );
}

std::string JwtService::base64url_decode(
    const std::string& encoded
)
{
    std::vector<unsigned char> decoded(
        encoded.size()
    );

    std::size_t decoded_size = 0;

    const int result =
        sodium_base642bin(
            decoded.data(),
            decoded.size(),
            encoded.c_str(),
            encoded.size(),
            nullptr,
            &decoded_size,
            nullptr,
            sodium_base64_VARIANT_URLSAFE_NO_PADDING
        );

    if (result != 0)
    {
        throw std::runtime_error(
            "Invalid JWT Base64Url value."
        );
    }

    decoded.resize(
        decoded_size
    );

    return std::string(
        reinterpret_cast<
            const char*
        >(
            decoded.data()
        ),
        decoded.size()
    );
}

std::string JwtService::sign(
    const std::string& signing_input
) const
{
    std::array<
        unsigned char,
        crypto_auth_hmacsha256_BYTES
    > signature{};

    crypto_auth_hmacsha256_state state;

    crypto_auth_hmacsha256_init(
        &state,
        signing_key_.data(),
        signing_key_.size()
    );

    crypto_auth_hmacsha256_update(
        &state,
        reinterpret_cast<
            const unsigned char*
        >(
            signing_input.data()
        ),
        static_cast<unsigned long long>(
            signing_input.size()
        )
    );

    crypto_auth_hmacsha256_final(
        &state,
        signature.data()
    );

    const std::string encoded =
        base64url_encode(
            signature.data(),
            signature.size()
        );

    sodium_memzero(
        signature.data(),
        signature.size()
    );

    return encoded;
}

long long JwtService::unix_time_now()
{
    return std::chrono::duration_cast<
        std::chrono::seconds
    >(
        std::chrono::system_clock::now()
            .time_since_epoch()
    ).count();
}

std::string JwtService::create_access_token(
    long long user_id,
    long long lifetime_seconds
) const
{
    if (user_id <= 0)
    {
        throw std::runtime_error(
            "Cannot create JWT for invalid user id."
        );
    }

    if (
        lifetime_seconds < 60 ||
        lifetime_seconds > 86400
    )
    {
        throw std::runtime_error(
            "JWT lifetime is outside the allowed range."
        );
    }

    const long long now =
        unix_time_now();

    std::array<
        unsigned char,
        16
    > token_id_bytes{};

    randombytes_buf(
        token_id_bytes.data(),
        token_id_bytes.size()
    );

    const std::string token_id =
        base64url_encode(
            token_id_bytes.data(),
            token_id_bytes.size()
        );

    nlohmann::json header = {
        {"alg", "HS256"},
        {"typ", "JWT"}
    };

    nlohmann::json payload = {
        {"iss", ISSUER},
        {"aud", AUDIENCE},
        {"sub", std::to_string(user_id)},
        {"iat", now},
        {"exp", now + lifetime_seconds},
        {"jti", token_id}
    };

    const std::string encoded_header =
        base64url_encode(
            header.dump()
        );

    const std::string encoded_payload =
        base64url_encode(
            payload.dump()
        );

    const std::string signing_input =
        encoded_header +
        "." +
        encoded_payload;

    return
        signing_input +
        "." +
        sign(signing_input);
}

JwtClaims JwtService::verify_access_token(
    const std::string& token
) const
{
    const auto parts =
        split_token(token);

    const std::string signing_input =
        parts[0] +
        "." +
        parts[1];

    const std::string supplied_signature =
        base64url_decode(
            parts[2]
        );

    if (
        supplied_signature.size() !=
        crypto_auth_hmacsha256_BYTES
    )
    {
        throw std::runtime_error(
            "JWT signature has invalid length."
        );
    }

    std::array<
        unsigned char,
        crypto_auth_hmacsha256_BYTES
    > expected_signature{};

    crypto_auth_hmacsha256_state state;

    crypto_auth_hmacsha256_init(
        &state,
        signing_key_.data(),
        signing_key_.size()
    );

    crypto_auth_hmacsha256_update(
        &state,
        reinterpret_cast<
            const unsigned char*
        >(
            signing_input.data()
        ),
        static_cast<unsigned long long>(
            signing_input.size()
        )
    );

    crypto_auth_hmacsha256_final(
        &state,
        expected_signature.data()
    );

    const int signatures_differ =
        sodium_memcmp(
            expected_signature.data(),
            supplied_signature.data(),
            expected_signature.size()
        );

    sodium_memzero(
        expected_signature.data(),
        expected_signature.size()
    );

    if (signatures_differ != 0)
    {
        throw std::runtime_error(
            "JWT signature verification failed."
        );
    }

    nlohmann::json header;
    nlohmann::json payload;

    try
    {
        header =
            nlohmann::json::parse(
                base64url_decode(
                    parts[0]
                )
            );

        payload =
            nlohmann::json::parse(
                base64url_decode(
                    parts[1]
                )
            );
    }
    catch (...)
    {
        throw std::runtime_error(
            "JWT JSON is invalid."
        );
    }

    if (
        header.value(
            "alg",
            std::string{}
        ) != "HS256" ||
        header.value(
            "typ",
            std::string{}
        ) != "JWT"
    )
    {
        throw std::runtime_error(
            "Unsupported JWT header."
        );
    }

    if (
        payload.value(
            "iss",
            std::string{}
        ) != ISSUER ||
        payload.value(
            "aud",
            std::string{}
        ) != AUDIENCE
    )
    {
        throw std::runtime_error(
            "JWT issuer or audience is invalid."
        );
    }

    if (
        !payload.contains("iat") ||
        !payload["iat"].is_number_integer() ||
        !payload.contains("exp") ||
        !payload["exp"].is_number_integer() ||
        !payload.contains("jti") ||
        !payload["jti"].is_string()
    )
    {
        throw std::runtime_error(
            "JWT claims are incomplete."
        );
    }

    const long long now =
        unix_time_now();

    const long long issued_at =
        payload["iat"].get<long long>();

    const long long expires_at =
        payload["exp"].get<long long>();

    if (
        issued_at >
        now + CLOCK_SKEW_SECONDS
    )
    {
        throw std::runtime_error(
            "JWT issue time is invalid."
        );
    }

    if (expires_at <= now)
    {
        throw std::runtime_error(
            "JWT has expired."
        );
    }

    if (expires_at <= issued_at)
    {
        throw std::runtime_error(
            "JWT expiry is invalid."
        );
    }

    JwtClaims claims;

    claims.user_id =
        parse_positive_user_id(
            payload
        );

    claims.issued_at =
        issued_at;

    claims.expires_at =
        expires_at;

    claims.token_id =
        payload["jti"]
            .get<std::string>();

    return claims;
}
