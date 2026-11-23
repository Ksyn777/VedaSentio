# VedaSentio — sprawdzanie odpowiedzi błędów Firebase FCM (#22)

## Zakres PR #49 po uporządkowaniu zależności

Ten PR bazuje na gałęzi PR #50 (`test/22-push-token-rotation-validation`) i dodaje **wyłącznie testowaną obsługę odpowiedzi FCM HTTP v1 po stronie backendu C++**. Logika tokenów i nawigacji Fluttera z PR #50 nie jest w nim dublowana ani cofana.

- `backend/src/push/FcmResponseParser.h`: parser odpowiedzi JSON. Wynik kwalifikuje token do wyłączenia tylko wtedy, gdy `error.details[]` zawiera tekstowy `errorCode: UNREGISTERED`. Nieprawidłowa struktura i nieudany odczyt JSON nie mogą skutkować dezaktywacją.
- `backend/src/push/PushNotificationService.cpp`: używa wydzielonego parsera zamiast lokalnej, nieprzetestowanej funkcji. Zachowano istniejącą ścieżkę dezaktywacji tokenów i obsługę pozostałych błędów.
- `backend/tools/fcm_response_parser_test.cpp`: 11 przypadków testowych, m.in. UNREGISTERED, INVALID_ARGUMENT, UNAVAILABLE, puste lub niepoprawne JSON.
- `backend/CMakeLists.txt`: rejestruje test w istniejącym CTest; zachowuje wszystkie obecne cele i testy backendu/MQTT.

## Odbiór i ograniczenia

Sprawdzić w GitHub Actions kompilację C++, uruchomienie CTest, Flutter, ESP32 i testy regresji alarmów na aktualnym commicie. Test parsera nie jest dowodem wysłania powiadomienia, dezaktywacji tokena w produkcyjnej bazie ani poprawnej pracy Firebase.

Na testowym telefonie, z prawdziwym testowym Firebase i bez publikowania sekretów, należy później zweryfikować token nieaktywny po odpowiedzi UNREGISTERED, dostarczenie oraz otwarcie alarmu. Dodatkowa luka: wyrejestrowanie tokena przy logout, Issue #51, wymaga osobnego, bezpiecznego rozwiązania przed użyciem współdzielonych urządzeń.

Fizyczny ESP32 i czujniki pozostają **ostatnim etapem**. Bez wdrożenia, bez zamykania Issue i bez automatycznego scalenia PR.
