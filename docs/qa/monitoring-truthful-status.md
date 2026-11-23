# VedaSentio — monitoring domu i wiarygodność prezentacji (#18)

## Decyzja projektowa
W systemie bezpieczeństwa **brak danych nie oznacza braku zagrożenia**. UI nie może prezentować zielonego, uspokajającego statusu, jeżeli nie ma aktywnych czujników lub ostatnie żądanie API zakończyło się błędem.

Wzorzec wizualny Figma: https://www.figma.com/design/MXDiWHTFJzgCl3L7x4qeHr

Kierunek: czytelny, spokojny panel kontrolny, neutralna biel, typografia z hierarchią, oszczędne akcenty kolorystyczne; czerwony alarm zachowuje pierwszeństwo. Bez atrap zdjęć domu, dekoracyjnych gradientów, sztucznych statystyk lub dodatkowych ekranów bez potrzeby.

## Scenariusze statusu

| Dane API | Prezentacja |
|---|---|
| Brak aktywnych czujników, brak alarmów | Monitoring nieaktywny; brak potwierdzenia bezpieczeństwa |
| Czujniki aktywne i online, brak alarmów | Brak aktywnych alarmów — stan ostatniego odczytu |
| Czujnik aktywny, ale offline, brak alarmów | Wymagana uwaga; liczba urządzeń online bez nieaktywnych urządzeń |
| Utrata połączenia po wcześniejszym zielonym odczycie | Stan niepotwierdzony i Dane nieaktualne |
| Aktywny alarm krytyczny, także po utracie łączności | ALARM; przy niedostępnym API dodatkowo „dane nieaktualne” |
| Nieudane pierwsze pobranie | Komunikat błędu i ponowienie, bez lokalnych danych demo |
| Powrót połączenia | Stan ponownie liczony wyłącznie z nowego wyniku backendu |

## Weryfikacja
- `mobile/test/home_monitoring_trust_test.dart`: sześć testów prezentacji stanu i utraty danych.
- `mobile/test/home_monitoring_api_contract_test.dart`: prawdziwy `AuthService` i `ApiClient` z lokalnymi odpowiedziami HTTP `MockClient`. Sprawdza JSON urządzeń, zmianę stanu drzwi po dwóch odświeżeniach i aktywny alarm SOS, który zmienia stan bezpieczeństwa.
- `flutter analyze` i `flutter test` w CI.
- PR #45 (#21) i PR #46 (#19) zostały już scalone do `master`. Ten PR zawiera wyłącznie zmiany monitoringu z #18, zachowując poprawkę blokującą wyświetlanie danych po HTTP 403. Do odbioru nadal wymagany jest test aplikacji z żywym backendem.

**Granice testów**: odpowiedzi HTTP są symulowane, chociaż korzystamy z właściwych tras i modeli. To test kontraktu klienta, **nie uruchomienie żywego backendu w połączeniu z Flutterem**, nie test fizycznego ESP32, nie test rzeczywistego door_001. Odbiór software-only z serwerem i testową bazą planujemy przed sprzętem.

## Kolejność dalszych prac (software-first)
1. Zintegrować i zatwierdzić istniejące PR-y przy zachowaniu zielonego CI.
2. Domknąć backend/API/Flutter z syntetycznymi danymi MQTT, testową bazą PostgreSQL, scenariuszami błędów i kontrolą uprawnień.
3. Osiągnąć docelowy UX w aplikacji, zrobić testy widgetowe, dostępności i odbiór na emulatorze lub testowym telefonie.
4. Zweryfikować powiadomienia push, archiwum, uruchomienie backendu i scenariusz demonstracyjny bez fizycznych czujników.
5. **Dopiero na końcu** zbudować fizyczne ESP32, połączyć czujniki z systemem, zweryfikować Wi-Fi/reconnect, poprawność danych i pełne E2E na sprzęcie.

Zmiana priorytetu nie oznacza uznania fizycznych testów za ukończone. Nie wolno uznawać systemu za certyfikowany system alarmowy.
