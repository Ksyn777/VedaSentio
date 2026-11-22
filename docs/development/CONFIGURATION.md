# Konfiguracja developerska VedaSentio

## 1. Backend i Docker

Skopiuj `.env.example` do lokalnego `.env` i uzupełnij wartości. Plik `.env` jest ignorowany przez Git.

Najważniejsze porty:
- PostgreSQL: `127.0.0.1:5433` — dostęp tylko z komputera deweloperskiego,
- MQTT: `1883` — dostęp z sieci lokalnej, aby ESP32 mogło połączyć się z brokerem,
- REST API: `127.0.0.1:8080` — obecnie dostęp lokalny.

Mosquitto wymaga lokalnego pliku:
`infrastructure/mosquitto/config/passwords`

Plik jest ignorowany przez Git i należy utworzyć go lokalnie narzędziem `mosquitto_passwd`.

## 2. ESP32

Skopiuj:

`firmware/door_contact_esp32/include/secrets.example.h`

jako:

`firmware/door_contact_esp32/include/secrets.h`

Następnie ustaw lokalnie:
- nazwę i hasło Wi-Fi,
- adres IP komputera z Mosquitto,
- użytkownika i hasło MQTT,
- identyfikator urządzenia.

`secrets.h` jest ignorowany przez Git.

## 3. Klucze backendu

Backend wymaga trzech kluczy:
- `VEDASENTIO_DATA_ENCRYPTION_KEY_B64`,
- `VEDASENTIO_LOOKUP_HMAC_KEY_B64`,
- `VEDASENTIO_JWT_SIGNING_KEY_B64`.

Kluczy nie zapisujemy w repozytorium.

## 4. Firebase

Powiadomienia push są opcjonalne w środowisku developerskim.

Jeśli `GOOGLE_APPLICATION_CREDENTIALS` nie jest ustawione, backend nadal zapisuje alarmy, ale nie wysyła automatycznych push.

Plik konta serwisowego Firebase również nie powinien trafić do repozytorium.
