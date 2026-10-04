#pragma once

#include <array>
#include <string>
#include <string_view>

#include <sodium.h>

class CryptoService
{
public:
    CryptoService(
        const std::string& data_encryption_key_b64,
        const std::string& lookup_hmac_key_b64
    );

    ~CryptoService();

    CryptoService(const CryptoService&) = delete;
    CryptoService& operator=(const CryptoService&) = delete;
    CryptoService(CryptoService&&) = delete;
    CryptoService& operator=(CryptoService&&) = delete;

    std::string encrypt_field(
        std::string_view plaintext,
        std::string_view context
    ) const;

    std::string decrypt_field(
        std::string_view encrypted_value_b64,
        std::string_view context
    ) const;

    std::string lookup_hmac_hex(
        std::string_view normalized_value
    ) const;

private:
    static std::array<unsigned char, crypto_aead_xchacha20poly1305_ietf_KEYBYTES>
    decode_encryption_key(const std::string& encoded);

    static std::array<unsigned char, crypto_auth_hmacsha256_KEYBYTES>
    decode_hmac_key(const std::string& encoded);

    static std::string encode_base64(
        const unsigned char* data,
        std::size_t size
    );

    static std::string decode_base64(
        std::string_view encoded
    );

    std::array<
        unsigned char,
        crypto_aead_xchacha20poly1305_ietf_KEYBYTES
    > data_encryption_key_{};

    std::array<
        unsigned char,
        crypto_auth_hmacsha256_KEYBYTES
    > lookup_hmac_key_{};
};
