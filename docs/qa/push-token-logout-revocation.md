# VedaSentio — wyrejestrowanie FCM i bezpieczne wylogowanie (#51)

## Problem i rozwiązanie

Na współdzielonym telefonie samo zatrzymanie strumienia `onTokenRefresh` nie wyłącza zapisanych w PostgreSQL tokenów starego użytkownika. Po wylogowaniu serwer może nadal wysyłać alarmy dotyczące jego gospodarstwa.

W tym etapie wprowadzono:
- uwierzytelniony `DELETE /api/mobile-devices/push-token` z JSON `{"fcm_token":"..."}`;
- SQL `UPDATE mobile_push_tokens SET is_active=FALSE ... WHERE user_id=$1 AND fcm_token=$2`, zawsze parametryzowany; brak dostępu do tokenów innych użytkowników i idempotentne `200 {"status":"unregistered"}` dla nieistniejących/obcych tokenów (bez ujawniania właściciela);
- rejestr `PushTokenRevocationRegistry` przechowuje **każdy token, którego rejestrację podjęto**, także jeśli POST zakończył się timeoutem (serwer mógł już zapisać wpis);
- zatrzymanie rotacji i doczekanie zakończenia istniejących rejestracji przed rozpoczęciem DELETE; odświeżane tokeny tego samego telefonu są obsługiwane wszystkie;
- wylogowanie z połączeniem: najpierw potwierdzona dezaktywacja, następnie usunięcie lokalnej sesji;
- przy awarii Internetu: **wyraźne ostrzeżenie**, opcje Ponów / Anuluj / Wyloguj mimo to; nie ma fałszywego potwierdzenia wyłączenia push;
- po wygaśnięciu JWT automatyczne wylogowanie bez żądania, którego i tak nie można autoryzować, z komunikatem ostrzegającym o pozostawionym tokenie.

Dla konta B podanie tokena konta A **nie zmienia wpisu**. Przy zalogowaniu na tym samym telefonie jako B rejestracja przez `UPSERT` przenosi ten sam token do B, nie tworzy drugiego rekordu.

## Testy automatyczne
- `mobile/test/push_logout_revocation_test.dart`: prawdziwe `AuthService` i `ApiClient` na `MockClient`, DELETE z JWT, 401/403, offline, brak potwierdzenia oraz kolejkowane tokeny i retry;
- `backend/tools/push_token_logout_api_test.cpp`, `scripts/test_push_token_logout_api.py`, `scripts/test_push_token_logout_linux.sh`: kompilacja prawdziwego API i auth na loopback, lokalny PostgreSQL, fikcyjne konta, tokeny A/B, testy uprawnień, idempotencji, walidacji, `is_active` i przeniesienia tokena między kontami;
- `.github/workflows/push-logout-regression.yml`: niezależny job Ubuntu24.04 + PostgreSQL17, 14 minut timeout, wyzwalany tylko zmianami właściwych plików. Używa jednorazowej bazy `vedasentio_push_revoke_ci`; skrypt odmawia użycia innych baz i hostów.
- istniejące standardowe CI: backend Windows, Flutter i kompilacja ESP32.

## Istotne ograniczenia / ryzyko resztkowe

1. **Wylogowanie mimo błędu Internetu nie wyrejestruje tokena na serwerze.** Nawet próba skasowania lokalnego tokena nie jest gwarancją usunięcia już zapisanej subskrypcji serwerowej. Nie można cofnąć push, który Firebase już dostarczył lub umieścił w kolejce.
2. Po świadomym wylogowaniu mimo błędu aplikacja usuwa lokalną sesję i listę tokenów; **nie wolno** wysyłać ich potem z JWT innego użytkownika. W takim scenariuszu użytkownik otrzymuje instrukcję: przy działającym Internecie zalogować się do poprzedniego konta i ponownie wylogować oraz zgłosić administratorowi konieczność wycofania starego tokena, jeśli nadal przychodzą powiadomienia. Dla już zmienionego tokena konieczna może być ręczna dezaktywacja przez administratora.
3. Prawdziwy test Firebase/Android/iOS wymaga fizycznego **telefonu**, serwera i testowych danych Firebase. Nie wymaga gotowego ESP32 — zdarzenia alarmowe można publikować syntetycznie przez MQTT. Żadne hasła ani klucze Google nie trafiają do repozytorium/CI.
4. Nie testowano rzeczywistego dostarczenia push, APNs ani odbioru po dłuższym czasie offline. System nie jest certyfikowanym alarmem medycznym/pożarowym.

## Odbiór na telefonie (software-only)
1. Na telefonie testowym z Androidem/iOS i FCM zaloguj konto A oraz zaakceptuj powiadomienia. Sprawdź `POST /api/mobile-devices/push-token` i wpis `is_active=TRUE` w bazie testowej.
2. Wyloguj konto A przy działającym Internetcie: w bazie wpis tego urządzenia ma `is_active=FALSE`; drugi telefon A ma pozostać aktywny.
3. Zaloguj konto B, zarejestruj ten sam telefon i wyślij alarm testowy do A: urządzenie B nie może otrzymać danych A.
4. Symuluj brak Internetu podczas logout: musi pojawić się ostrzeżenie. Wybierz Ponów po przywróceniu sieci, a następnie sprawdź wyłączenie tokena w bazie.
5. Sprawdź oddzielnie ścieżkę „Wyloguj mimo to” — aplikacja nie może twierdzić, że push wyłączono. Zweryfikuj procedurę ręcznej revokacji.
6. Wymuś odnowienie tokena FCM i potwierdź, że zarówno starszy token, jak i nowy token mogą być wyłączone przy logout.

**ESP32 i montaż czujników zostają na końcu projektu.** Nie scalać/nie zamykać #51 przed ręcznym odbiorem.
