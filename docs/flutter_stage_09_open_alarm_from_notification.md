# Otwieranie alarmu po kliknięciu powiadomienia

## Cel etapu

Celem etapu jest przejście z systemowego powiadomienia Android bezpośrednio
do gospodarstwa i alarmu, którego dotyczy komunikat.

Backend przesyła w danych FCM między innymi `alarm_id` oraz `home_id`.
Aplikacja wykorzystuje te wartości do wyboru właściwego gospodarstwa i alarmu.

## Obsługiwane przypadki

Mechanizm działa, gdy aplikacja jest w tle oraz gdy aplikacja została wcześniej
zamknięta i jest uruchamiana kliknięciem powiadomienia.

Jeżeli sesja użytkownika nie została jeszcze przywrócona, informacja o alarmie
pozostaje oczekująca. Po przywróceniu sesji lub po zalogowaniu aplikacja próbuje
otworzyć właściwy ekran.

## Sprawdzenie dostępu

Aplikacja nie ufa samemu `home_id` z powiadomienia. Gospodarstwo musi znajdować
się na liście gospodarstw pobranej z backendu dla zalogowanego użytkownika.
Jeżeli użytkownik nie ma do niego dostępu, ekran alarmu nie zostaje otwarty.

## Widok alarmu

Po kliknięciu powiadomienia otwierany jest `HomeDetailsScreen` właściwego
gospodarstwa. Na początku ekranu pojawia się sekcja `Alarm otwarty z
powiadomienia`.

Aplikacja wyszukuje alarm po `alarm_id` najpierw w alarmach aktywnych, a potem
w historii. Dzięki temu można zobaczyć alarm również wtedy, gdy został już
zakończony przed otwarciem aplikacji.

## Firebase Messaging

Dla aplikacji działającej w tle używany jest `FirebaseMessaging.onMessageOpenedApp`.
Dla aplikacji uruchomionej kliknięciem powiadomienia używany jest
`FirebaseMessaging.instance.getInitialMessage()`.

Nie dodano nowej biblioteki. Wykorzystano istniejący pakiet
`firebase_messaging`.
