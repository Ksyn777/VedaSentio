# Etap 12 - alarm gazu

## Cel

Celem etapu jest potwierdzenie pełnej obsługi zdarzenia wykrycia gazu od MQTT do aplikacji mobilnej.

Backend posiada wspólny mechanizm reguł alarmowych. Dla gazu używane są zdarzenia:

- `gas_detected` - otwarcie alarmu,
- `gas_cleared` - automatyczne zakończenie alarmu.

Alarm gazu ma poziom `critical`.

## Przepływ

`gas_detected` trafia przez MQTT do backendu. Zdarzenie jest zapisywane w PostgreSQL, a `AlarmRepository` tworzy aktywny alarm typu `gas`. Nowy alarm uruchamia wysyłkę FCM do opiekunów przypisanych do gospodarstwa.

Powtórne `gas_detected`, gdy alarm jest już aktywny, aktualizuje istniejący alarm i nie tworzy drugiego wpisu. Dzięki temu kolejne odczyty czujnika nie powodują powstawania wielu równoległych alarmów.

Po odebraniu `gas_cleared` alarm jest oznaczany jako `resolved` i pozostaje w historii.

## Aplikacja mobilna

Flutter pokazuje alarm jako `Alarm gazu`. Ponieważ jego poziom to `critical`, główny stan gospodarstwa przechodzi w czerwony stan `ALARM`.

## Powiadomienie

Dla nowego alarmu gazowego backend wysyła powiadomienie:

- tytuł: `VedaSentio - WYKRYTO GAZ`,
- treść: `Wykryto gaz - <nazwa domu>`.

Kliknięcie powiadomienia korzysta z istniejącej nawigacji `home_id` i `alarm_id`, dlatego otwiera właściwe gospodarstwo i alarm.

## Testy

Test backendu sprawdza:

- utworzenie krytycznego alarmu gazu,
- brak duplikatu po kolejnym `gas_detected`,
- zakończenie po `gas_cleared`,
- zachowanie alarmu w historii.

Test Fluttera sprawdza etykietę alarmu gazu oraz przejście aplikacji w czerwony stan alarmowy.

Na tym etapie zdarzenie MQTT może być generowane skryptem testowym. Fizyczny czujnik gazu i ESP32 zostaną podłączone w osobnym etapie sprzętowym.
