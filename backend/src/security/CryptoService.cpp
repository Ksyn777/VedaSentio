#include "CryptoService.h"

#include <stdexcept>
#include <vector>

namespace
{
constexpr unsigned char FORMAT_VERSION = 1;

template <std::size_t ExpectedSize>
std::array<unsigned char, ExpectedSize> decode_fixed_key(
    const std::string& encoded,
    const char* key_name
)
{
    std::array<unsigned char, ExpectedSize> key{};
    std::size_t decoded_size = 0;

    const int result = sodium_base642bin(
        key.data(),
        key.size(),
        encoded.c_str(),
        encoded.size(),
        nullptr,
        &decoded_size,
        nullptr,
        sodium_base64_VARIANT_ORIGINAL
    );

    if (result != 0 || decoded_size != key.size())
    {
        sodium_memzero(
            key.data(),
            key.size()
        );

        throw std::runtime_error(
            std::string(key_name) +
            " must be a Base64 encoded 32-byte key."
        );
    }

    return key;
}
}

CryptoService::CryptoService(
    const std::string& data_encryption_key_b64,
    const std::string& lookup_hmac_key_b64
)
{
    if (sodium_init() < 0)
    {
        throw std::runtime_error(
            "Unable to initialize libsodium."
        );
    }

    data_encryption_key_ =
        decode_encryption_key(
            data_encryption_key_b64
        );

    lookup_hmac_key_ =
        decode_hmac_key(
            lookup_hmac_key_b64
        );
}

CryptoService::~CryptoService()
{
    sodium_memzero(
        data_encryption_key_.data(),
        data_encryption_key_.size()
    );

    sodium_memzero(
        lookup_hmac_key_.data(),
        lookup_hmac_key_.size()
    );
}

std::array<
    unsigned char,
    crypto_aead_xchacha20poly1305_ietf_KEYBYTES
>
CryptoService::decode_encryption_key(
    const std::string& encoded
)
{
    return decode_fixed_key<
        crypto_aead_xchacha20poly1305_ietf_KEYBYTES
    >(
        encoded,
        "VEDASENTIO_DATA_ENCRYPTION_KEY_B64"
    );
}

std::array<
    unsigned char,
    crypto_auth_hmacsha256_KEYBYTES
>
CryptoService::decode_hmac_key(
    const std::string& encoded
)
{
    return decode_fixed_key<
        crypto_auth_hmacsha256_KEYBYTES
    >(
        encoded,
        "VEDASENTIO_LOOKUP_HMAC_KEY_B64"
    );
}

std::string CryptoService::encode_base64(
    const unsigned char* data,
    std::size_t size
)
{
    const std::size_t encoded_size =
        sodium_base64_ENCODED_LEN(
            size,
            sodium_base64_VARIANT_ORIGINAL
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
        sodium_base64_VARIANT_ORIGINAL
    );

    if (!encoded.empty() &&
        encoded.back() == '\0')
    {
        encoded.pop_back();
    }

    return encoded;
}

std::string CryptoService::decode_base64(
    std::string_view encoded
)
{
    std::vector<unsigned char> decoded(
        encoded.size()
    );

    std::size_t decoded_size = 0;

    const int result = sodium_base642bin(
        decoded.data(),
        decoded.size(),
        encoded.data(),
        encoded.size(),
        nullptr,
        &decoded_size,
        nullptr,
        sodium_base64_VARIANT_ORIGINAL
    );

    if (result != 0)
    {
        throw std::runtime_error(
            "Invalid Base64 encrypted value."
        );
    }

    decoded.resize(decoded_size);

    return std::string(
        reinterpret_cast<const char*>(
            decoded.data()
        ),
        decoded.size()
    );
}

std::string CryptoService::encrypt_field(
    std::string_view plaintext,
    std::string_view context
) const
{
    std::array<
        unsigned char,
        crypto_aead_xchacha20poly1305_ietf_NPUBBYTES
    > nonce{};

    randombytes_buf(
        nonce.data(),
        nonce.size()
    );

    std::vector<unsigned char> ciphertext(
        plaintext.size() +
        crypto_aead_xchacha20poly1305_ietf_ABYTES
    );

    unsigned long long ciphertext_size = 0;

    const int result =
        crypto_aead_xchacha20poly1305_ietf_encrypt(
            ciphertext.data(),
            &ciphertext_size,
            reinterpret_cast<const unsigned char*>(
                plaintext.data()
            ),
            static_cast<unsigned long long>(
                plaintext.size()
            ),
            reinterpret_cast<const unsigned char*>(
                context.data()
            ),
            static_cast<unsigned long long>(
                context.size()
            ),
            nullptr,
            nonce.data(),
            data_encryption_key_.data()
        );

    if (result != 0)
    {
        throw std::runtime_error(
            "Field encryption failed."
        );
    }

    ciphertext.resize(
        static_cast<std::size_t>(
            ciphertext_size
        )
    );

    std::vector<unsigned char> packed;
    packed.reserve(
        1 +
        nonce.size() +
        ciphertext.size()
    );

    packed.push_back(FORMAT_VERSION);

    packed.insert(
        packed.end(),
        nonce.begin(),
        nonce.end()
    );

    packed.insert(
        packed.end(),
        ciphertext.begin(),
        ciphertext.end()
    );

    return encode_base64(
        packed.data(),
        packed.size()
    );
}

std::string CryptoService::decrypt_field(
    std::string_view encrypted_value_b64,
    std::string_view context
) const
{
    const std::string packed_string =
        decode_base64(
            encrypted_value_b64
        );

    const auto* packed =
        reinterpret_cast<
            const unsigned char*
        >(
            packed_string.data()
        );

    const std::size_t minimum_size =
        1 +
        crypto_aead_xchacha20poly1305_ietf_NPUBBYTES +
        crypto_aead_xchacha20poly1305_ietf_ABYTES;

    if (packed_string.size() < minimum_size)
    {
        throw std::runtime_error(
            "Encrypted value is too short."
        );
    }

    if (packed[0] != FORMAT_VERSION)
    {
        throw std::runtime_error(
            "Unsupported encrypted value format."
        );
    }

    const unsigned char* nonce =
        packed + 1;

    const unsigned char* ciphertext =
        nonce +
        crypto_aead_xchacha20poly1305_ietf_NPUBBYTES;

    const std::size_t ciphertext_size =
        packed_string.size() -
        1 -
        crypto_aead_xchacha20poly1305_ietf_NPUBBYTES;

    std::vector<unsigned char> plaintext(
        ciphertext_size
    );

    unsigned long long plaintext_size = 0;

    const int result =
        crypto_aead_xchacha20poly1305_ietf_decrypt(
            plaintext.data(),
            &plaintext_size,
            nullptr,
            ciphertext,
            static_cast<unsigned long long>(
                ciphertext_size
            ),
            reinterpret_cast<const unsigned char*>(
                context.data()
            ),
            static_cast<unsigned long long>(
                context.size()
            ),
            nonce,
            data_encryption_key_.data()
        );

    if (result != 0)
    {
        throw std::runtime_error(
            "Unable to decrypt field: "
            "authentication failed."
        );
    }

    plaintext.resize(
        static_cast<std::size_t>(
            plaintext_size
        )
    );

    return std::string(
        reinterpret_cast<const char*>(
            plaintext.data()
        ),
        plaintext.size()
    );
}

std::string CryptoService::lookup_hmac_hex(
    std::string_view normalized_value
) const
{
    std::array<
        unsigned char,
        crypto_auth_hmacsha256_BYTES
    > digest{};

    crypto_auth_hmacsha256_state state;

    crypto_auth_hmacsha256_init(
        &state,
        lookup_hmac_key_.data(),
        lookup_hmac_key_.size()
    );

    crypto_auth_hmacsha256_update(
        &state,
        reinterpret_cast<const unsigned char*>(
            normalized_value.data()
        ),
        static_cast<unsigned long long>(
            normalized_value.size()
        )
    );

    crypto_auth_hmacsha256_final(
        &state,
        digest.data()
    );

    std::array<
        char,
        crypto_auth_hmacsha256_BYTES * 2 + 1
    > hex{};

    sodium_bin2hex(
        hex.data(),
        hex.size(),
        digest.data(),
        digest.size()
    );

    sodium_memzero(
        digest.data(),
        digest.size()
    );

    return std::string(
        hex.data()
    );
}
