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

Po zaakceptowaniu zmian sprawdź logowanie oraz przełączanie pomiędzy użytkownikiem z przypisanym i nieprzypisanym gospodarstwem w Flutter. Zaloguj się jako `viewer` i sprawdź odmowę potwierdzenia alarmu, następnie jako `caregiver` i `owner` sprawdź potwierdzenie. Sprawdź komunikaty przy zerwaniu sieci. Bez lokalnego odbioru nie zamykaj zadania #17.
