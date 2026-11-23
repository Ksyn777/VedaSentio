# API VedaSentio — regresja kontroli dostępu (#17)

## Zakres

Test uruchamia prawdziwe `ApiServer.cpp`, `UserRepository.cpp`, `JwtService.cpp`, `CryptoService.cpp`, `Database.cpp` i `AlarmRepository.cpp` oraz lokalny PostgreSQL 17. Do bazy wprowadzane są wyłącznie fikcyjne konta CI i dwa testowe gospodarstwa. HTTP nasłuchuje wyłącznie na `127.0.0.1:28900`.

Test obejmuje istniejące, używane przez Flutter API. Nie dodaje nowych endpointów ani nie osłabia kontroli JWT, haseł i szyfrowania danych użytkownika.

Kontrolowane przypadki:
- poprawne logowanie i odpowiedź `/api/me`, `/api/homes`;
- 401 dla żądań bez Bearer JWT, fałszywego tokena i błędnego hasła;
- 403 dla obcego gospodarstwa, także przy próbie potwierdzenia alarmu;
- widoczność własnych urządzeń, zdarzeń, ostatniego zdarzenia i alarmów;
- rola `viewer` nie może potwierdzać alarmu; `caregiver` i `owner` mogą;
- `limit` jest dodatnią liczbą dziesiętną, bez niejawnego przyjmowania `10abc`; wartości powyżej 500 są ograniczane do 500;
- nieprawidłowy filtr `active` i nieprawidłowy/za duży `alarm_id` dają 400, a nie 500;
- wymagania formatu i limitu rozmiaru żądania logowania oraz rejestracji fikcyjnego tokenu push.

## Ograniczenia

To rzeczywisty test HTTP API z PostgreSQL, ale nie uruchamia MQTT, firmware, Firebase ani telefonu. Nie potwierdza testu UI Flutter na fizycznym urządzeniu. Test bazuje na sztucznych użytkownikach i alarmach, nie wolno go używać na bazie użytkownika.

## Izolacja i koszty

Skrypt `scripts/test_api_access_linux.sh` **odmawia** pracy, jeżeli host bazy to nie `127.0.0.1` lub nazwa bazy to nie `vedasentio_api_ci`. Klucze JWT oraz szyfrowania danych są generowane tylko w pamięci w trakcie testu. Do repozytorium nie trafiają rzeczywiste sekrety. Skrypt kończy działanie serwera i usuwa dane testowe, a runner GitHub Actions usuwa kontener bazy po zakończeniu.

Workflow to jedno zadanie na standardowym Ubuntu 24.04, z timeoutem 14 minut. Nie dodaje płatnej usługi.

## Odbiór lokalny

### Aktualizacja po PR #41, #56 i #57 — 2026-11-23

Gałąź PR #44 została zaktualizowana zwykłym merge z `origin/master`
(`7f624ad5`), bez konfliktów i bez przepisywania historii. Parser MQTT,
reconnect, regresja alarmów oraz główny workflow CI pozostały bez zmian.

Rozszerzony zestaw ma **91 kontroli HTTP**. Oprócz dotychczasowych przypadków
obejmuje brak/nieprawidłowy JWT na kolejnych trasach, prawidłowo podpisany,
ale wygasły JWT, błędny JSON i typy pól, puste limity i prefiks `+`, historię
zakończonego alarmu, zachowanie autora ponownego potwierdzenia oraz walidację
rozmiaru i treści rejestracji push. Nienumeryczne ID nie pasują do trasy
potwierdzania i zwracają standardowe 404 routera; nie jest to odpowiedź JSON
API. Numeryczne zero i overflow nadal dają kontrolowane JSON 400.

Wykonano lokalnie w jednorazowych kontenerach Ubuntu 24.04 i PostgreSQL 17:

- HTTP API i sprzątanie danych: **91/91 PASS**;
- istniejąca regresja alarmów #41: **PASS**, z ASan/UBSan według runnera;
- istniejący test parsera #56: **PASS**;
- istniejący test cyklu MQTT #57: **PASS**, z symulowanym transportem;
- składnia Python/Bash i `git diff --check`: **PASS**.

PostgreSQL testowy nie publikował portów na hoście; dane trzymano w tmpfs.
Oddzielne bazy `vedasentio_api_ci` i `vedasentio_alarm_ci` nie współdzieliły
danych z istniejącymi projektami. Repozytorium było zamontowane tylko do
odczytu; kompilacja odbywała się na kopii w kontenerze. Libpqxx 7.10.7
zweryfikowano względem commita używanego w workflow. Nie wykonywano testu
fizycznego ESP32, telefonu, dostarczania FCM ani pełnego MQTT → API → Flutter.

Po zaakceptowaniu zmian sprawdź logowanie oraz przełączanie pomiędzy użytkownikiem z przypisanym i nieprzypisanym gospodarstwem w Flutter. Zaloguj się jako `viewer` i sprawdź odmowę potwierdzenia alarmu, następnie jako `caregiver` i `owner` sprawdź potwierdzenie. Sprawdź komunikaty przy zerwaniu sieci. Bez lokalnego odbioru nie zamykaj zadania #17.
