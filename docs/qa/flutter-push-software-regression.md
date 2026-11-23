# Push VedaSentio — automatyczna regresja bez prawdziwego Firebase (#22)

## Zakres zweryfikowany w kodzie i CI
- Powiadomienia FCM mogą zawierać wyłącznie bezpieczny cel: poprawny identyfikator gospodarstwa oraz **dodatni** identyfikator alarmu. Odrzucane są puste wartości, wartości ujemne/zerowe, obce typy i niepoprawne ciągi (np. \`4abc\`).
- Nawigacja otwiera gospodarstwo tylko, gdy znajduje się na aktualnej liście gospodarstw zalogowanego użytkownika. Powiadomienie **nie przyznaje uprawnień** — serwer wciąż musi weryfikować JWT i dostęp.
- Podczas aktywnej sesji Flutter subskrybuje \`FirebaseMessaging.instance.onTokenRefresh\` i wysyła nowy token do istniejącego endpointu rejestracji. Nie wysyła ponownie tego samego tokena po udanym zapisie.
- Rejestracje są sekwencyjne, nieudana jest możliwa do ponowienia, a zmiana konta lub wylogowanie zatrzymuje nasłuch starej sesji. Wygasły JWT (401) podczas rejestracji czyści lokalny token; 403 i brak sieci tego nie robią.
- Tokeny, klucze Google i szczegóły błędów mogące zawierać dane wrażliwe nie są wypisywane do logów.

## Testy automatyczne (bez FCM / bez sprzętu)
- \`mobile/test/push_token_registration_coordinator_test.dart\`: rotacja tokena, deduplikacja, niepowodzenie i ponowna próba, puste wartości, wylogowanie i odrzucenie kolejnych zdarzeń, nowa sesja, błędy strumienia.
- \`mobile/test/push_registration_stage_test.dart\`: prawdziwy \`AuthService\` i \`ApiClient\` na fikcyjnych żądaniach HTTP; 200, 401, 403, awaria sieci, poprawny Bearer JWT i payload.
- \`mobile/test/alarm_notification_target_test.dart\`: niepoprawne/właściwe cele push oraz filtr dostępu użytkownika.
- Wcześniejszy [PR #43](https://github.com/Ksyn777/VedaSentio/pull/43) testuje, że awaria push **nie cofa alarmu w PostgreSQL**. Ten PR nie uruchamia prawdziwego FCM i nie testuje jego dostarczenia.

## Co pozostaje do ręcznego testu na telefonie i prawdziwym Firebase
1. Wprowadzić konfigurację własnego projektu Firebase i konto serwisowe backendu wyłącznie lokalnie (nie do repozytorium i nie do CI).
2. Wyrazić zgodę na powiadomienia na Androidzie/iOS, wykonać logowanie, potwierdzić rejestrację tokena przez testowe API.
3. Wyzwolić syntetyczny alarm MQTT, sprawdzić zapis w bazie, wysyłkę przez FCM i faktyczne dostarczenie na telefon.
4. Kliknąć powiadomienie z aplikacji zamkniętej i w tle: powinno otworzyć właściwy dom i alarm; obce gospodarstwo musi zostać odrzucone.
5. Wymusić rotację tokena oraz sprawdzić \`UNREGISTERED\` na backendzie.
6. Sprawdzić przypadki braku \`GOOGLE_APPLICATION_CREDENTIALS\`, błędu dostarczenia i braku Internetu.

### Ograniczenie prywatności na wylogowaniu
Zatrzymanie nasłuchu tokena po wylogowaniu **nie dezaktywuje już zarejestrowanego tokena po stronie serwera**. Do bezpiecznego korzystania ze współdzielonych telefonów potrzebny jest osobny, autoryzowany mechanizm wyrejestrowania tokena FCM w API i obsłużenia jego porażek; nie twierdzimy, że ten PR rozwiązuje to ryzyko. Do czasu domknięcia mechanizmu aplikacja nie powinna działać na współdzielonym urządzeniu zawierającym rzeczywiste dane.

## Polityka etapów
Nie zamykać #22 bez rzeczywistego testu FCM na telefonie. Budowa fizycznego ESP32 i integracja czujników pozostają **ostatnim etapem** całego projektu. Nie otwierać dostępu do bazy PostgreSQL przez Internet ani nie używać repozytorium do przechowywania rzeczywistych sekretów.
