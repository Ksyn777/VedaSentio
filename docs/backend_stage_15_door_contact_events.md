# Etap 15 - kontaktron drzwi

## Cel

Dodanie zdarzeń z kontaktronu jako danych kontekstowych do późniejszej analizy zachowań.

## Zdarzenia

- `door_opened` - drzwi zostały otwarte,
- `door_closed` - drzwi zostały zamknięte.

## Ważna decyzja projektowa

Samo otwarcie lub zamknięcie drzwi nie tworzy alarmu. Jest to zwykłe zdarzenie aktywności domowej.

Dane są zapisywane w `sensor_events`, dzięki czemu w przyszłości moduł analityczny będzie mógł wykorzystywać je do budowania profilu typowego zachowania, np. częstotliwości otwierania drzwi, pór wychodzenia z domu lub długiego braku aktywności.

Alarm może powstać dopiero w późniejszej warstwie analitycznej, gdy zachowanie znacząco odbiega od wyuczonego wzorca.

## Co zmieniono

1. Rozszerzono test backendu o urządzenie `door_contact`.
2. Test sprawdza zapis `door_opened` i `door_closed`.
3. Test potwierdza, że zwykłe zdarzenie drzwi nie tworzy alarmu.
4. Test sprawdza historię zdarzeń i ostatni znany stan drzwi.
5. `database/dev_seed.sql` dodaje testowe urządzenie `door_001`.
6. Dodano test Fluttera dla czytelnych etykiet zdarzeń drzwi.
7. Dodano prosty skrypt MQTT do testowania otwarcia i zamknięcia.

## Przepływ

`door_opened / door_closed -> MQTT -> backend -> sensor_events -> API -> Flutter`

Na tym etapie nie jest wysyłane powiadomienie FCM, ponieważ pojedyncze otwarcie drzwi nie jest samo w sobie zagrożeniem.
