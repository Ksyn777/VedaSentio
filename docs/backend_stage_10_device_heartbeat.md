# Etap 10 - heartbeat i status urządzenia online/offline

## Cel

System powinien wiedzieć nie tylko, czy czujnik zgłosił zagrożenie, ale również
czy samo urządzenie nadal komunikuje się z backendem.

## Zasada działania

Urządzenie wysyła przez MQTT zdarzenie `heartbeat` na ten sam temat co pozostałe
zdarzenia:

`vedasentio/{home_id}/{device_id}/event`

Przykładowy payload:

```json
{
  "event_type": "heartbeat",
  "value": true,
  "timestamp": "2026-10-16T16:00:00Z"
}
```

Backend najpierw sprawdza, czy urządzenie jest zarejestrowane i aktywne, a
następnie aktualizuje `devices.last_seen_at`.

Każde prawidłowe zdarzenie z urządzenia również aktualizuje `last_seen_at`.
Oznacza to, że naciśnięcie SOS albo zgłoszenie gazu także potwierdza, że
urządzenie działa i ma kontakt z backendem.

## Dlaczego heartbeat nie trafia do sensor_events

Heartbeat jest wiadomością techniczną wysyłaną często. Zapisywanie każdego
heartbeat do tabeli zdarzeń powodowałoby szybki wzrost liczby rekordów bez
wartości dla historii zagrożeń.

Dlatego heartbeat aktualizuje tylko czas ostatniego kontaktu. Zwykłe zdarzenia
nadal są zapisywane w `sensor_events`.

## Status online

Urządzenie jest uznawane za online, gdy:

- jest aktywne,
- posiada `last_seen_at`,
- ostatni kontakt nastąpił nie dawniej niż 2 minuty temu.

Po przekroczeniu dwóch minut API zwraca `is_online = false`. Nie jest do tego
potrzebny osobny wątek sprawdzający urządzenia. Status jest obliczany podczas
pobierania listy urządzeń.

## Aplikacja mobilna

Ekran gospodarstwa pokazuje teraz:

- Online,
- Offline,
- Urządzenie nieaktywne,
- czas ostatniego kontaktu.

Ekran odświeża dane cyklicznie, dlatego stan urządzenia może zmienić się na
offline bez nowego komunikatu MQTT.

## Zakres tego etapu

Ten etap wykrywa i pokazuje brak komunikacji. Nie tworzy jeszcze alarmu ani
powiadomienia push dla urządzenia offline. Takie powiadomienie można dodać jako
kolejny etap po potwierdzeniu poprawności heartbeat.
