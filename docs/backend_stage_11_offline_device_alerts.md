# Etap 11 - alarm urządzenia offline

## Cel

Samo oznaczenie urządzenia jako offline w aplikacji nie wystarcza, ponieważ
opiekun nie musi mieć aplikacji otwartej. Backend powinien sam wykryć brak
komunikacji i przekazać ostrzeżenie.

## Zasada działania

Urządzenie jest traktowane jako online, jeżeli `last_seen_at` nie jest starsze
niż 2 minuty. Backend co 10 sekund sprawdza stan aktywnych urządzeń.

Jeżeli urządzenie:

- było już wcześniej widziane przez system,
- jest aktywne,
- nie komunikowało się przez ponad 2 minuty,

to backend tworzy alarm:

- `alarm_type = device_offline`,
- `severity = warning`,
- `status = active`.

Dla jednego urządzenia może istnieć tylko jeden otwarty alarm tego typu.
Powtarzające się kontrole nie tworzą kolejnych alarmów ani kolejnych
powiadomień.

## Powiadomienie

Po utworzeniu nowego alarmu wykorzystywany jest istniejący mechanizm FCM.
Powiadomienie zawiera nazwę urządzenia i gospodarstwa. Dane FCM nadal zawierają
`alarm_id`, `home_id`, `device_id`, `alarm_type` i `severity`, dlatego
kliknięcie komunikatu prowadzi do właściwego gospodarstwa.

## Powrót urządzenia

Każdy poprawny komunikat MQTT aktualizuje `last_seen_at`. Jeżeli dla urządzenia
istnieje otwarty alarm `device_offline`, zostaje on automatycznie zakończony.
Heartbeat nie jest zapisywany jako zwykłe zdarzenie sensoryczne.

## Ważne założenie

Urządzenie, które nigdy jeszcze nie skontaktowało się z backendem i ma puste
`last_seen_at`, nie generuje alarmu offline. Zapobiega to alarmom podczas
pierwszej konfiguracji urządzenia.
