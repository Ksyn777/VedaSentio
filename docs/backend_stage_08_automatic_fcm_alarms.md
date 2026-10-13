# Automatyczne powiadomienia alarmowe FCM

## Cel etapu

Celem etapu jest wyslanie powiadomienia push bez recznego korzystania z
Firebase Console.

Przeplyw:

czujnik / test MQTT
-> backend C++
-> zapis zdarzenia
-> utworzenie nowego alarmu
-> pobranie telefonow opiekunow
-> Firebase Cloud Messaging
-> Android

Powiadomienie jest wysylane tylko przy utworzeniu nowego alarmu.
Powtorzenie tego samego aktywnego zdarzenia aktualizuje istniejacy alarm,
ale nie generuje kolejnego powiadomienia.

## Zmiany w backendzie

`AlarmRepository::process_event` zwraca teraz nowo utworzony alarm.

`MqttClient` po utworzeniu alarmu przekazuje go do
`PushNotificationService`.

`PushNotificationService`:

- pobiera aktywne tokeny FCM z tabeli `mobile_push_tokens`,
- wybiera uzytkownikow przypisanych do gospodarstwa z rola `owner` lub
  `caregiver`,
- pobiera nazwe gospodarstwa,
- uzyskuje krotkotrwaly token OAuth 2.0,
- wysyla wiadomosc przez FCM HTTP v1,
- ustawia priorytet Androida na `high`,
- oznacza token FCM jako nieaktywny, jesli FCM zwroci `UNREGISTERED`.

Blad wysylki push nie usuwa alarmu i nie odrzuca zapisanego zdarzenia.
Alarm w backendzie pozostaje zrodlem prawdy.

## Uwierzytelnienie serwera Firebase

Backend korzysta z pliku JSON konta uslugi Firebase.

Plik jest sekretem serwerowym i nie moze trafic do Git.

Docelowa lokalizacja developerska:

`%APPDATA%\VedaSentio\firebase-service-account.json`

Sciezka jest przekazywana do backendu przez standardowa zmienna:

`GOOGLE_APPLICATION_CREDENTIALS`

Skrypt:

`scripts/load_firebase_server_credentials.ps1`

ustawia te zmienna dla aktualnego procesu PowerShell.

## FCM HTTP v1

Backend wysyla wiadomosci do:

`POST https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`

Autoryzacja:

`Authorization: Bearer <krotkotrwaly_token_OAuth2>`

Zakres OAuth:

`https://www.googleapis.com/auth/firebase.messaging`

Do polaczen HTTPS na Windows wykorzystywane jest natywne WinHTTP.
Podpis JWT konta uslugi wykonywany jest przez OpenSSL przy uzyciu RS256.

## Odbiorcy

Powiadomienie otrzymuja aktywne urzadzenia aktywnych uzytkownikow, ktorzy
maja przypisanie do danego gospodarstwa z rola:

- `owner`,
- `caregiver`.

Rola `viewer` nie otrzymuje automatycznego alarmu w tym etapie.

## Przykladowy alarm SOS

Tytul:

`VedaSentio - ALARM SOS`

Tresc:

`Nacisnieto przycisk SOS - Dom testowy`

W danych powiadomienia przesylane sa dodatkowo:

- `alarm_id`,
- `home_id`,
- `device_id`,
- `alarm_type`,
- `severity`.

Pozwoli to w kolejnym etapie otwierac odpowiedni ekran po kliknieciu
powiadomienia.
