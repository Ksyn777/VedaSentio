# Etap 21 - filtrowanie aktywności po dacie

## Cel

Rozbudowanie zakładki Aktywność o możliwość ograniczenia listy zdarzeń do konkretnego dnia.

## Dodane elementy

Na ekranie Aktywność dodano filtry:

- Dzisiaj,
- Wczoraj,
- Wybierz datę,
- Wszystkie.

Po wybraniu konkretnej daty aplikacja pokazuje wyłącznie zdarzenia z tego dnia. Jeżeli dla wybranego dnia nie ma danych, użytkownik otrzymuje czytelny komunikat.

## Implementacja

Filtrowanie jest wykonywane po stronie aplikacji Flutter na podstawie pola `received_at` pobranych zdarzeń. Nie zmieniono API ani backendu.

Wybranie innego gospodarstwa zeruje filtr daty, żeby filtr z poprzedniego domu nie wpływał na nowy widok.

## Dalszy rozwój

Przy bardzo dużej historii aktywności filtrowanie po dacie można przenieść do backendu i PostgreSQL, aby aplikacja nie musiała pobierać dużej liczby zdarzeń.
