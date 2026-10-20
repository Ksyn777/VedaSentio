# Etap 19 - dopracowanie Aktywności, Historii i Konta

## Cel

Uproszczenie prezentacji danych technicznych i poprawa czytelności trzech głównych zakładek aplikacji.

## Aktywność

Identyfikatory urządzeń nie są już główną informacją dla użytkownika. Zdarzenie jest prezentowane razem z nazwą logicznego źródła, na przykład `Drzwi wejściowe`, `Czujnik dymu` lub `Przycisk SOS`.

Dodano kontekstowe etykiety stanu, między innymi `Otwarte`, `Zamknięte`, `Wykryto` i `Brak zagrożenia`.

## Historia alarmów

Dodano lokalne filtry:

- Wszystkie,
- Krytyczne,
- Ostrzeżenia.

Filtrowanie odbywa się po danych już pobranych z backendu i nie wymaga nowego endpointu.

## Konto

Dane kontaktowe zostały opisane etykietami `E-mail` i `Telefon`. Informacje o bezpiecznej sesji, przypisanych gospodarstwach i powiadomieniach zostały uporządkowane w jednej sekcji.

## Technologie

Nie dodano nowych bibliotek. Zmiany dotyczą wyłącznie warstwy Flutter UI.
