# VedaSentio — instrukcje dla Codexa i innych agentów

Przed zmianą kodu przeczytaj ten plik, `docs/backlog/ROADMAP.md`, `docs/backlog/WORKFLOW.md`, główny backlog #30 oraz właściwe Issue.

## Cel projektu

VedaSentio to system IoT wspomagający opiekę nad osobą starszą lub wymagającą nadzoru. System zbiera zdarzenia z urządzeń ESP32, przesyła je przez MQTT do backendu C++, zapisuje dane w PostgreSQL i pokazuje stan domu oraz alarmy w aplikacji Flutter.

System nie jest certyfikowanym wyrobem medycznym ani zamiennikiem profesjonalnego systemu alarmowego.

## Aktualna architektura

- firmware: ESP32 + Arduino/PlatformIO,
- broker: Eclipse Mosquitto,
- backend: C++20,
- MQTT: Paho MQTT C++,
- baza: PostgreSQL + libpqxx,
- JSON: nlohmann/json,
- API HTTP: cpp-httplib,
- mobile: Flutter,
- push: Firebase Cloud Messaging.

Główny topic:
`vedasentio/{home_id}/{device_id}/event`

Przykładowy payload:
`{"timestamp":"2026-10-22T08:14:04Z","event_type":"heartbeat","value":true}`

Heartbeat aktualizuje status urządzenia. Zwykłe eventy sensorów są zapisywane jako zdarzenia. Alarmy tworzą obecnie reguły dla SOS, dymu, CO, gazu, zalania oraz offline urządzenia. Nie zmieniaj znaczenia eventów bez osobnego Issue.

## Twarde zasady bezpieczeństwa

- Nie commituj `.env`, `secrets.h`, haseł MQTT/DB, kluczy JWT, kluczy szyfrujących ani danych kont Firebase.
- Nie loguj sekretów.
- PostgreSQL ma pozostać dostępny lokalnie/developersko zgodnie z obecną konfiguracją; nie wystawiaj go publicznie.
- Nie otwieraj usług do Internetu i nie wdrażaj produkcyjnie bez osobnej zgody.
- Nie usuwaj kontroli dostępu do gospodarstw ani JWT tylko po to, aby test przeszedł.
- Błąd push nie może usuwać ani cofać alarmu zapisanego w bazie.
- Nie twierdź, że test sprzętowy przeszedł, jeśli nie został wykonany na prawdziwym ESP32/czujniku.
- Nie wpisuj wymyślonych progów bezpieczeństwa dla gazu, CO lub dymu, jeśli konkretnego sensora i kalibracji nie opisano w Issue.

## Proces: 1 TASK = 1 PR

1. Wybierz najbliższy odblokowany TASK z #30 / `ROADMAP.md`.
2. Sprawdź zależności i aktualny kod na `master`.
3. Napisz krótki plan: pliki, zakres, testy, ryzyka.
4. Utwórz gałąź z aktualnego `master`:
   - `feat/<numer-issue>-krotki-opis`
   - `fix/<numer-issue>-krotki-opis`
   - `test/<numer-issue>-krotki-opis`
   - `docs/<numer-issue>-krotki-opis`
5. Nie zmieniaj niezwiązanych modułów.
6. Nie resetuj cudzej pracy, nie używaj `--force` i nie usuwaj nieznanych plików.
7. Po zmianie uruchom adekwatne testy/build oraz `git diff --check`.
8. Otwórz PR z `Refs #<issue>`.
9. W PR wpisz: zakres, rzeczywisty wynik testów, ograniczenia i instrukcję lokalnego odbioru.
10. Nie wykonuj automatycznego merge, deploy ani zamknięcia Issue. Użytkownik odbiera zmianę lokalnie.

## Zasady modułów

### Firmware ESP32
- Zachowaj prosty kod możliwy do wyjaśnienia na obronie.
- Nie blokuj głównej pętli długimi `delay`, jeśli można użyć `millis()`.
- Sensory powinny wysyłać zdarzenie po zmianie stabilnego stanu, a nie w każdej iteracji pętli.
- Używaj wspólnego publishera zdarzeń zamiast kopiować budowanie JSON/MQTT do każdego sensora.
- `secrets.h` pozostaje lokalny.

### Backend C++
- Nie zapisuj błędnego payloadu tylko po to, aby parser był bardziej tolerancyjny.
- Waliduj topic, payload i dostęp użytkownika.
- Nie twórz duplikatów aktywnego alarmu dla tego samego urządzenia/typu.
- Heartbeat służy do `last_seen` i online/offline.
- Zmiana reguł alarmowych wymaga testu regresyjnego.

### Flutter
- Dane produkcyjne pochodzą z API, nie z lokalnych stałych demo.
- 401 ma prowadzić do wygaśnięcia sesji/logowania.
- 403 ma pozostać odmową dostępu.
- Nie ukrywaj błędów jako sukcesu.
- UI powinno pozostać czytelne na małym telefonie.

## Kontrole przed PR

Firmware:
- w katalogu projektu PlatformIO: `pio run`
- test sprzętowy tylko gdy fizyczne ESP32 jest dostępne.

Flutter:
- `flutter analyze`
- `flutter test`
- build/smoke jeśli zmiana dotyczy uruchomienia.

Backend:
- `cmake --build backend/build --config Debug` jeśli build jest skonfigurowany,
- uruchom odpowiednie istniejące narzędzia/testy dla zmienianej logiki,
- przy zmianie DB/API sprawdź scenariusz pozytywny i negatywny.

Repo:
- `git status --short`
- `git diff --check`

## Bramka ukończenia

Kod gotowy nie oznacza zamkniętego TASK-a. Używaj #1. Issue zamyka użytkownik dopiero po lokalnym odbiorze.
