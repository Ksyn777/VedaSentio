# VedaSentio — architektura, przepływ danych i MQTT

Dokument opisuje stan `master` na 23.11.2026. Walidator MQTT, odporność reconnect, poprawki monitoringu Fluttera, rotacja tokenów FCM i parser `UNREGISTERED` są już obecne w kodzie. Autoryzowane wyrejestrowanie tokena FCM po wylogowaniu (PR #52) jest już w `master`; przy awarii sieci aplikacja ostrzega, że powiadomienia mogą nadal docierać do urządzenia. Odbiór z prawdziwym Firebase i telefonem pozostaje otwarty.

## 1. Przepływ end-to-end

```text
[ESP32 / testowy PowerShell]
        | publikacja MQTT QoS 1
        v
[Mosquitto 2]  topic: vedasentio/{home_id}/{device_id}/event
        |
        v
[C++20 backend / Paho MQTT]
        | weryfikacja urządzenia i aktualizacja last_seen
        | heartbeat -> aktualizacja połączenia bez wpisu historii
        | inne zdarzenie -> zapis w sensor_events
        | analiza alarmu -> alarms (aktywny / potwierdzony / zakończony)
        | opcjonalnie próba FCM HTTP v1 dla opiekunów
        v
[PostgreSQL 17]
        ^
        | autoryzowane zapytania JWT + kontrola ról w API HTTP
        |
[Flutter / monitoring, historia, szczegóły alarmu]
        ^
        | opcjonalnie FCM: kliknięcie -> home_id + alarm_id
        |
[telefon opiekuna]
```

Backend lokalnie: MQTT `tcp://127.0.0.1:1883`, klient `vedasentio_backend`, subskrypcja `vedasentio/+/+/event`, QoS 1; HTTP API `127.0.0.1:8080`. Obie lokalizacje są aktualnie stałymi w `backend/src/main.cpp`.

## 2. Topic MQTT

```text
vedasentio/{home_id}/{device_id}/event
```

Przykład: `vedasentio/home_001/door_001/event`.

- `home_id` i `device_id` określają istniejący, zarejestrowany w bazie dom i aktywne urządzenie.
- Wspólny topic jest używany dla zdarzeń i heartbeat. `+` w subskrypcji obejmuje pojedynczy segment identyfikatora.
- `SensorEventParser` wymaga dokładnie czterech segmentów topicu. Identyfikatory domu i urządzenia mają maksymalnie 64 znaki i mogą zawierać tylko litery, cyfry, `_` i `-`. Zły prefiks/sufiks, pusty segment lub dodatkowe segmenty są odrzucane.
- Broker nie dopuszcza anonimowych klientów (`allow_anonymous false`), wymaga lokalnego pliku haseł i w tej konfiguracji **nie używa TLS**. Do sieci publicznych obecna konfiguracja jest nieodpowiednia.

## 3. Payload JSON

Każdy event powinien zawierać poniższe trzy pola. Nie przekazujemy loginów, JWT, haseł ani danych osobowych w MQTT.

```json
{
  "timestamp": "2026-11-22T12:00:00Z",
  "event_type": "door_opened",
  "value": true
}
```

| Pole | Typ | Znaczenie |
| --- | --- | --- |
| `timestamp` | string | wymagany czas UTC ISO 8601 z `Z`, np. `2026-11-22T12:00:00Z`; dopuszczona część ułamkowa sekund |
| `event_type` | string | rozpoznawana nazwa zdarzenia |
| `value` | boolean | `true` dla `heartbeat`, `door_opened`, `sos_pressed` i zdarzeń `*_detected`; `false` dla `door_closed`, `sos_resolved` i zdarzeń `*_cleared` |

`home_id` i `device_id` są **w topiku**, nie muszą być powielane w JSON. Backend zapisuje także czas odbioru `received_at` nadawany przez PostgreSQL. Aktualny `SensorEventParser` odrzuca payloady przekraczające **4096 bajtów**, nieprawidłowe identyfikatory topicu, nieobsługiwane `event_type`, wartości inne niż boolean, niezgodność `value` z typem zdarzenia i błędny czas UTC. Reguły te są walidacją wejścia, **nie** oznaczają certyfikowanego działania sensorów ani bezpieczeństwa całego systemu.

## 4. Zdarzenia i alarmy

| `event_type` | Znaczenie |
| --- | --- |
| `heartbeat` | odświeżenie `last_seen_at`; brak wpisu w historii sensorów |
| `door_opened` | otwarcie drzwi |
| `door_closed` | zamknięcie drzwi |
| `sos_pressed` | wywołanie alarmu SOS |
| `sos_resolved` | zakończenie alarmu SOS |
| `flood_detected` / `flood_cleared` | wykrycie i ustąpienie zalania |
| `smoke_detected` / `smoke_cleared` | wykrycie i ustąpienie dymu |
| `co_detected` / `co_cleared` | wykrycie i ustąpienie tlenku węgla |
| `gas_detected` / `gas_cleared` | wykrycie i ustąpienie gazu |

`device_offline` jest **typem alarmu wyznaczanym przez backend**, nie wymaga publikacji `event_type=device_offline` przez ESP32. Backend aktualizuje `last_seen_at` po odebraniu komunikatu urządzenia, rozpatruje alarm offline i przegląda stany urządzeń okresowo. Aktualne progi i reguły należy odczytać z kodu, nie zakładać certyfikowanych progów bezpieczeństwa; przed fizycznym podłączeniem sensorów konieczna będzie kalibracja.

W bazie przechowywane są odrębne zdarzenia (`sensor_events`) i alarmy (`alarms`) powiązane z `home_id`/`device_id`. Backend może utworzyć alarm typu SOS, flood, smoke, CO, gas lub offline. Przy braku poprawnej konfiguracji Firebase **alarm nadal powinien zostać zapisany**, ale push może nie zostać wysłany. Nie jest to gwarancja natychmiastowego powiadomienia.

## 5. REST API, tożsamość i role

API jest lokalne, korzysta z JWT (HS256, kryptografia klucza po stronie serwera) i sprawdza przynależność do gospodarstwa. Zasadnicze trasy:

| Metoda | Trasa | Cel |
| --- | --- | --- |
| GET | `/api/health` | zdrowie API, bez logowania |
| POST | `/api/auth/login` | uwierzytelnienie |
| GET | `/api/me` | dane zalogowanego użytkownika |
| GET | `/api/homes` | gospodarstwa, do których ma dostęp użytkownik |
| GET | `/api/homes/{home_id}/devices` | urządzenia |
| GET | `/api/homes/{home_id}/events` | historia zdarzeń |
| GET | `/api/homes/{home_id}/devices/{device_id}/latest` | ostatnie zdarzenie urządzenia |
| GET | `/api/homes/{home_id}/alarms` | alarmy i historia |
| POST | `/api/homes/{home_id}/alarms/{alarm_id}/acknowledge` | potwierdzenie alarmu przez uprawnioną rolę |
| POST | `/api/mobile-devices/push-token` | rejestracja tokena urządzenia dla powiadomień |
| DELETE | `/api/mobile-devices/push-token` | dezaktywacja własnego tokena FCM na podstawie JWT i `fcm_token` w JSON |

Role: `owner`, `caregiver`, `viewer`. `viewer` ma dostęp do odczytu w ramach przypisanego gospodarstwa, ale nie może potwierdzać alarmu. JWT nie daje automatycznie dostępu do każdego domu. Specyfikacja: [API i autoryzacja](api_authentication.md). Przy poprawnym wyrejestrowaniu API zwraca `{"status":"unregistered"}`; jeżeli serwer jest niedostępny, nie wolno zakładać, że wpis FCM został dezaktywowany. Sprawdzenie na prawdziwym urządzeniu pozostaje konieczne.

## 6. Środowisko, porty, ograniczenia

- **PostgreSQL** przez Docker Compose: `127.0.0.1:5433` na Windows, w kontenerze `5432`; nie wystawiaj do Internetu.
- **Mosquitto**: `1883` na interfejsach hosta; hasło wymagane, bez TLS; ogranicz zaporą do zaufanych adresów.
- **Backend API**: `127.0.0.1:8080` — nie jest jeszcze publiczną usługą HTTPS.
- **Flutter na Androidzie**: lokalne `adb reverse tcp:8080 tcp:8080`, aby uzyskać dostęp do backendu bez publicznego wystawiania API.
- **Firebase**: opcjonalne `GOOGLE_APPLICATION_CREDENTIALS` dla backendu, wyłącznie plik lokalny, ignorowany przez Git. FCM wymaga testowego konta i urządzenia w osobnym odbiorze.
- **Sekrety**: `.env`, firmware `secrets.h`, plik haseł MQTT oraz poświadczenia Firebase nie należą do repozytorium.
- **Stan realizacji**: green CI/kompilacja firmware ≠ działający czujnik; montaż i podłączenie ESP32 są **ostatnim etapem** projektu.

Praktyczny szybki start i komendy testu bez urządzenia znajdują się w [README](../README.md). Plan pracy: [backlog](backlog/ROADMAP.md), [reguły pracy](../AGENTS.md).
