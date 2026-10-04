#include "../src/security/CryptoService.h"

#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>

namespace
{
std::string require_env(
    const char* name
)
{
    const char* value =
        std::getenv(name);

    if (value == nullptr ||
        *value == '\0')
    {
        throw std::runtime_error(
            std::string(
                "Missing environment variable: "
            ) + name
        );
    }

    return value;
}
}

int main()
{
    try
    {
        CryptoService crypto(
            require_env(
                "VEDASENTIO_DATA_ENCRYPTION_KEY_B64"
            ),
            require_env(
                "VEDASENTIO_LOOKUP_HMAC_KEY_B64"
            )
        );

        const std::string plaintext =
            "Jan Kowalski";

        const std::string context =
            "demo.person_name";

        const std::string encrypted =
            crypto.encrypt_field(
                plaintext,
                context
            );

        const std::string decrypted =
            crypto.decrypt_field(
                encrypted,
                context
            );

        std::cout
            << "[CRYPTO] Plaintext: "
            << plaintext
            << '\n';

        std::cout
            << "[CRYPTO] Ciphertext: "
            << encrypted
            << '\n';

        std::cout
            << "[CRYPTO] Decrypted: "
            << decrypted
            << '\n';

        if (decrypted != plaintext)
        {
            std::cerr
                << "[CRYPTO] Round-trip FAILED.\n";

            return 1;
        }

        std::cout
            << "[CRYPTO] Round-trip OK.\n";

        const std::string lookup =
            crypto.lookup_hmac_hex(
                "jan@example.com"
            );

        std::cout
            << "[CRYPTO] Lookup HMAC: "
            << lookup
            << '\n';

        bool wrong_context_rejected = false;

        try
        {
            static_cast<void>(
                crypto.decrypt_field(
                    encrypted,
                    "demo.phone"
                )
            );
        }
        catch (const std::exception&)
        {
            wrong_context_rejected = true;
        }

        if (!wrong_context_rejected)
        {
            std::cerr
                << "[CRYPTO] Context protection FAILED.\n";

            return 1;
        }

        std::cout
            << "[CRYPTO] Context protection OK.\n";

        return 0;
    }
    catch (const std::exception& error)
    {
        std::cerr
            << "[CRYPTO] Error: "
            << error.what()
            << '\n';

        return 1;
    }
}
