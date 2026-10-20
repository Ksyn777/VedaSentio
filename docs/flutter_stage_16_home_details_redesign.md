# Etap 16 - redesign ekranu szczegółów domu

## Cel

Zmiana wyglądu ekranu VedaSentio na spokojniejszy, bardziej produktowy interfejs inspirowany zaakceptowanym mockupem.

## Założenia

- brak gradientów,
- ciepłe jasne tło,
- duże zaokrąglenia kart,
- pełny zielony kolor dla stanu `Wszystko OK`,
- pełny pomarańczowy kolor dla stanu `Ostrzeżenie`,
- pełny czerwony kolor dla stanu `ALARM`,
- pełny czerwony przycisk `Potwierdź alarm`,
- zdjęcie domu pozostaje placeholderem do późniejszej podmiany przez użytkownika,
- zachowana istniejąca logika backendu, auto-refresh, alarmy, historia, status online/offline i otwieranie alarmu z powiadomienia.

## Zmiany

Przebudowano `home_details_screen.dart` bez zmiany API i modeli danych. Dodano nowe lokalne komponenty prezentacyjne dla statusu bezpieczeństwa, monitoringu, urządzeń, historii alarmów i aktywności.

Nie dodano nowych bibliotek.
