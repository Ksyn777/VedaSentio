# VedaSentio — rejestracja telefonu do powiadomień push

## Cel etapu

Celem etapu jest przygotowanie aplikacji mobilnej i backendu do późniejszego
wysyłania powiadomień alarmowych przez Firebase Cloud Messaging.

W tym etapie system jeszcze nie wysyła powiadomień.

Powstaje natomiast pełna rejestracja telefonu:

aplikacja Flutter
-> Firebase Cloud Messaging
-> token FCM
-> REST API VedaSentio
-> PostgreSQL

## Flutter

Do aplikacji dodano biblioteki:

- `firebase_core`
- `firebase_messaging`

`firebase_core` odpowiada za połączenie aplikacji z projektem Firebase.

`firebase_messaging` odpowiada za uzyskanie tokenu FCM i późniejszą obsługę
powiadomień.

Po poprawnym zalogowaniu lub przywróceniu istniejącej sesji aplikacja:

1. sprawdza, czy działa na Androidzie lub iOS,
2. inicjalizuje Firebase,
3. prosi użytkownika o zgodę na powiadomienia,
4. pobiera token FCM,
5. wysyła token do backendu.

Na Windowsie mechanizm jest pomijany, dzięki czemu dotychczasowa wersja
desktopowa może nadal służyć do testowania pozostałych funkcji.

## Backend

Dodano endpoint:

`POST /api/mobile-devices/push-token`

Endpoint wymaga poprawnego JWT.

Przykładowe dane wejściowe:

```json
{
  "fcm_token": "...",
  "platform": "android"
}
```

Backend nie zwraca tokenu w odpowiedzi.

## PostgreSQL

Dodano tabelę:

`mobile_push_tokens`

Tabela przechowuje:

- identyfikator użytkownika,
- token FCM,
- platformę mobilną,
- informację, czy token jest aktywny,
- datę utworzenia,
- datę ostatniej rejestracji,
- datę ostatniej zmiany.

Token FCM ma ograniczenie unikalności. Ponowna rejestracja tego samego telefonu
aktualizuje istniejący rekord zamiast tworzyć duplikat.

## Dlaczego token zapisujemy na backendzie

Backend będzie później odpowiedzialny za wybór opiekunów przypisanych do domu
i wysłanie alarmu na ich telefony.

Telefon nie powinien sam decydować, czy ma zostać poinformowany o alarmie.
Backend posiada informacje o:

- użytkownikach,
- przypisaniu użytkowników do gospodarstw,
- aktywnych alarmach,
- rolach owner/caregiver/viewer.

Dzięki temu w kolejnym etapie backend będzie mógł pobrać odpowiednie tokeny
FCM i wysłać alarm tylko do właściwych osób.

## Konfiguracja Firebase

Kod nie zawiera identyfikatora projektu Firebase ani plików konfiguracyjnych
konkretnego projektu.

Po wgraniu patcha należy skonfigurować własny projekt Firebase dla aplikacji
Android. Dane projektu Firebase nie są generowane sztucznie w kodzie.
