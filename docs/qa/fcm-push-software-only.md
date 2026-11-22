# VedaSentio — testy powiadomień push bez fizycznego ESP32 (#22)

## Zakres automatyczny

Sprawdzenia są **realną logiką produkcyjną**, ale **nie udają wysłanego powiadomienia Firebase**.

Flutter:
- Parsowanie danych otwarcia alarmu z FCM `home_id`, `alarm_id`, opcjonalne inne pola; tylko dodatni identyfikator dziesiętny jest akceptowany.
- Powiadomienie można skierować do domu jedynie wtedy, kiedy jest na liście gospodarstw bieżącej sesji. Jest to kontrola klienta, **nie zastępuje** kontroli JWT w API.
- Testowe android/iOS rejestrują token przez prawdziwy `AuthService` + `ApiClient` i fikcyjny klient HTTP; sprawdza się metodę POST, nagłówek Bearer i JSON.
- Brak tokenu lub platforma inna niż android/iOS nie wywołuje API; 401 usuwa zapisaną sesję, 403 i problem sieci zachowują ją bez fałszywego sukcesu.
- Brak uruchamiania Firebase w tych testach; bez prawdziwych urządzeń i bez danych kont.

Backend:
- Odpowiedź FCM HTTP v1 jest analizowana przez testowalny parser `FcmResponseParser.h`. Token jest kwalifikowany do dezaktywacji **jedynie dla** `error.details[].errorCode == "UNREGISTERED"`.
- Test C++ obejmuje 11 przypadków: poprawne UNREGISTERED, inne kody, błędy przejściowe, niepoprawne struktury i niepoprawny JSON.
- Istniejąca logika zapisu alarmu niezależnie od błędu push była testowana osobno w PR #43. Ten PR nie testuje prawdziwego wysyłania przez Google.
- Brak `GOOGLE_APPLICATION_CREDENTIALS` w backendzie wyłącza wysyłkę push w `main.cpp` bez wyłączania zapisu alarmów. Funkcja nie potrzebuje sekretu dla testów.

## Pozostały odbiór na telefonie — etap software-only, przed ESP32

1. W izolowanym środowisku skonfiguruj Firebase przez własne bezpieczne dane lokalne (nigdy w repozytorium).
2. Zaloguj użytkownika `owner` lub `caregiver`; sprawdź rejestrację prawdziwego tokenu FCM i nadane zgody systemowe.
3. Wyślij **syntetyczne** zdarzenie SOS przez testowy Mosquitto i PostgreSQL; potwierdź zapis alarmu, odbiór powiadomienia i poprawny widok jego szczegółów w Flutter.
4. Otwórz powiadomienie w aplikacji w tle i po zimnym uruchomieniu.
5. Sprawdź nieprawidłowy `alarm_id`, odmowę dostępu do obcego domu oraz wygaśnięcie sesji. Nie otwieraj nieuprawnionych danych.
6. Sprawdź brak credentials, błąd połączenia z Google i zdezaktywowany token.
7. Zachowaj wyniki (bez logowania tokenów ani kluczy) w notatce odbioru.

Test z fizycznym ESP32 i czujnikami jest **ostatnim etapem**, ale prawdziwe FCM można zweryfikować wcześniej na testowym telefonie ze sztucznie opublikowanym zdarzeniem MQTT.

## Ograniczenia i koszty

Brak produkcyjnego Firebase, urządzenia fizycznego, prawdziwego tokenu, zewnętrznych żądań push w CI. Nie wprowadzamy dodatkowych płatnych usług. Bez deploy, automatycznego merge, zamknięcia Issue i zmian `docs/thesis/ENGINEERING_LOG.md`.
