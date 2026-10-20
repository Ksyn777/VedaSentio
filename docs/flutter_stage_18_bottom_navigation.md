# Etap 18 - główna nawigacja aplikacji

## Cel

Uporządkowanie głównej struktury aplikacji VedaSentio i oddzielenie czterech najważniejszych obszarów używanych przez opiekuna.

## Dodana nawigacja

Dolny pasek zawiera cztery sekcje:

- Dom - lista gospodarstw i wejście do monitoringu,
- Aktywność - ostatnie zdarzenia z czujników,
- Historia - alarmy i ostrzeżenia,
- Konto - dane użytkownika, informacje o zabezpieczeniu sesji i wylogowanie.

## Aktywność

Ekran pobiera ostatnie zdarzenia z backendu dla wybranego gospodarstwa. Zdarzenia `heartbeat` są ukryte, ponieważ są technicznym mechanizmem kontroli połączenia i nie powinny zaśmiecać widoku użytkownika.

## Historia

Historia alarmów korzysta z istniejącego endpointu backendu i pokazuje typ alarmu, urządzenie, poziom ważności, status oraz czas rozpoczęcia i zakończenia.

## Konto

Informacja o bezpiecznym przechowywaniu tokena została przeniesiona z głównego dashboardu do ekranu Konto. Dzięki temu ekran Dom skupia się wyłącznie na gospodarstwach i monitoringu.

## Backend

Nie dodano nowych endpointów. W `AuthService` dodano dwie proste metody korzystające z już istniejącego API:

- `loadHomeEvents`,
- `loadHomeAlarms`.

## Biblioteki

Nie dodano nowych bibliotek.
