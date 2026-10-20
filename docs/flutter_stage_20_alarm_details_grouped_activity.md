# Etap 20 - szczegóły alarmu i grupowanie aktywności

## Cel

Rozwinięcie interfejsu bez zmiany backendu i istniejącego modelu danych.

## Zmiany

### Aktywność

Zdarzenia są grupowane według dnia:

- Dzisiaj,
- Wczoraj,
- starsze daty w formacie DD.MM.RRRR.

Heartbeat nadal nie jest pokazywany jako aktywność użytkownika.

### Historia alarmów

Karty alarmów są teraz klikalne. Po wybraniu alarmu otwierany jest ekran szczegółów.

### Szczegóły alarmu

Ekran pokazuje:

- typ alarmu,
- poziom zagrożenia,
- status,
- źródło,
- identyfikator urządzenia,
- czas rozpoczęcia,
- czas potwierdzenia, jeżeli istnieje,
- czas zakończenia, jeżeli istnieje,
- sposób zakończenia alarmu.

Dane pochodzą z istniejącego modelu Alarm. Nie dodano nowego endpointu ani biblioteki.

## Znaczenie projektowe

Historia nie służy wyłącznie do pokazania listy zdarzeń. Opiekun może otworzyć pojedynczy alarm i sprawdzić jego przebieg bez przeglądania danych technicznych w bazie.
