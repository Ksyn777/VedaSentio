# VedaSentio — application-level encryption

## Goal

Personally identifiable information (PII), such as names, addresses,
telephone numbers and e-mail addresses, is intended to be encrypted by
the C++ backend before being written to PostgreSQL.

## Field encryption

The `CryptoService` module uses XChaCha20-Poly1305 authenticated
encryption through libsodium.

For each encrypted field:
- a new random nonce is generated,
- the field value is encrypted and authenticated,
- a logical field context is used as authenticated additional data,
- the stored payload contains a format version, nonce and ciphertext,
- the complete payload is Base64 encoded for storage in a TEXT column.

Example contexts:
- `users.email`
- `profiles.first_name`
- `profiles.phone`

Using context as authenticated additional data means ciphertext copied
to a different logical field cannot be successfully decrypted using a
different context.

## Searchable identifiers

Randomized encryption cannot be directly searched using equality.

For values which must be found efficiently, such as a normalized e-mail
address, the design uses a separate HMAC-SHA-256 lookup token.

Example future columns:

email_encrypted TEXT NOT NULL
email_lookup_hmac CHAR(64) UNIQUE NOT NULL

The HMAC uses an independent lookup key.

## Passwords

Passwords must NOT use reversible field encryption.

The user authentication module will store passwords using Argon2id
password hashing.

## Keys

Two independent 32-byte keys are used:
- `VEDASENTIO_DATA_ENCRYPTION_KEY_B64`
- `VEDASENTIO_LOOKUP_HMAC_KEY_B64`

The keys are not stored in PostgreSQL and must not be committed to Git.

For development, the supplied PowerShell script generates temporary
keys in the current terminal process.

For production, keys should be supplied through a dedicated secret
manager or KMS.

## Threat model

This layer is intended to protect personal data if an attacker obtains
only a database dump, database backup, or direct database contents.

It does not protect plaintext from an attacker who fully compromises
the running backend host and obtains both application access and the
encryption keys.

Additional production controls will therefore include authentication,
authorization, TLS, least privilege, audit logging, operating-system
hardening, secure secret storage and a key-rotation strategy.
