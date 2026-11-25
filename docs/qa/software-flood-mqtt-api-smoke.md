# Zalanie — rzeczywisty software E2E w izolowanym QA

Refs #63, #26, #29, #61. Bazą jest PR #62, commit `3b74971`. PR #58 (SOS) i #60 (diagnostyka) pozostają niezależne. Test wykorzystuje syntetyczne MQTT; nie potwierdza działania fizycznego sensora ani telefonu.

## Automatyczny odbiór PowerShell 7 / Windows 11

Z katalogu tej gałęzi, z Docker Desktop Linux na lokalnym named pipe i z gotowym backendem:

```powershell
cmake --build backend/build --config Debug --parallel 2
ctest --test-dir backend/build -C Debug --output-on-failure
./scripts/test_isolated_qa.ps1 -BackendPath ./backend/build/Debug/vedasentio_backend.exe
./scripts/test_flood_smoke.ps1
./scripts/test_isolated_qa_integration.ps1 -ConfirmIsolatedEnvironment
```

Pierwszą konfigurację CMake/vcpkg opisuje [izolowane QA](isolated-software-demo.md). Nie uruchamiaj istniejącego Compose ani migracji na bazie użytkownika. Integracja korzysta wyłącznie z własnej nowej bazy na 15433, Mosquitto na 28883 i API na 18080. Istniejące usługi 1883/5433 pozostają uruchomione. Brak wolnych portów przerywa test. Test używa start/stop z #62 bez zmian ich kodu.

Runner startuje QA, sprawdza tożsamość i wykonuje `database/qa/flood_seed.sql` wyłącznie w nowym kontenerze DB. Seed dodaje `home_001/flood_001`, typ `flood_sensor`, nazwę `Czujnik zalania QA`, aktywność true. Nie zmienia istniejącego seeda drzwi/SOS i nie wymaga migracji schematu.

Następnie istniejący mechanizm tworzy fikcyjnego użytkownika i JWT. Smoke drzwi sprawdza otwarcie/zamknięcie; smoke zalania sprawdza trzy publikacje i odpowiadające im alarmy. Istniejąca regresja alarmów używa tej samej jednorazowej bazy. `finally` sprząta QA według pierwotnych zasad własności i porównuje konfigurację, mounty oraz czasy startu wcześniejszych kontenerów. Błąd testu jest propagowany; nie usuwa się rekordów w celu uzyskania sukcesu. Dane tmpfs są usuwane dopiero przez normalny stop całego testowego QA.

## Ręczny odbiór

W nowym terminalu, bez wczytywania istniejącego `.env`:

```powershell
./scripts/start_isolated_qa.ps1 -ConfirmIsolatedEnvironment
$id = $global:VEDASENTIO_QA_ID
. ./scripts/flood_smoke_common.ps1
Assert-FloodQaInstance $id $env:VEDASENTIO_API_BASE_URL $env:VEDASENTIO_TEST_MQTT_CONTAINER
$state = Get-Content (Get-QaStatePath $id) -Raw | ConvertFrom-Json
Get-Content ./database/qa/flood_seed.sql -Raw | docker exec -i $state.Db psql -U $env:VEDASENTIO_DB_USER -d $env:VEDASENTIO_DB_NAME -v ON_ERROR_STOP=1
if ($LASTEXITCODE) { throw 'QA seed failed' }
./scripts/create_dev_user.ps1
# Fikcyjne dane, home_001, owner lub caregiver.
./scripts/login_api_dev.ps1
try {
    ./scripts/smoke_flood_mqtt_api.ps1 -QaId $id -TimeoutSeconds 15
} finally {
    ./scripts/stop_isolated_qa.ps1 -Id $id -ConfirmStop
}
```

Parametry smoke: `-QaId` (domyślnie globalny ID ze startu), `-ApiBaseUrl`, `-MqttContainer`, `-TimeoutSeconds` 1–60. URL i kontener domyślnie pochodzą ze zmiennych ustawionych przez start. JWT pozostaje w `$global:VEDASENTIO_ACCESS_TOKEN`; nigdy go nie drukuj.

Przed pierwszą publikacją smoke sprawdza lokalny Docker, stan instancji, nazwy/pełne ID/etykiety/porty kontenerów, wspólną sieć, tożsamość backendu i właściciela nasłuchu API. Potem sprawdza dostęp do urządzeń gospodarstwa i aktywne `flood_001`. Istniejący alarm `active` lub `acknowledged` blokuje test. Każda publikacja ponownie sprawdza własność QA. To kontrola środowiska developerskiego, nie zabezpieczenie przed administratorem hosta modyfikującym jednocześnie stan i procesy.

## Co oznacza PASS

1. `flood_detected=true`: nowe zdarzenie o właściwym ID, urządzeniu, wartości i czasie UTC; nowy alarm `flood/warning/active`, właściwe źródło i ostatnie zdarzenie.
2. Drugie `flood_detected=true`: ten sam alarm, niezmieniony `source_event_id`, `last_event_id` wskazujący zdarzenie drugiej publikacji; jeden otwarty alarm.
3. `flood_cleared=false`: ten sam alarm w historii ze statusem `resolved`, `resolution_source=sensor`, niepustym `resolved_at` i właściwym `last_event_id`; brak otwartego alarmu zalania.

Wszystkie potwierdzenia pochodzą z autoryzowanych `/api/homes/home_001/events` i `/alarms` (active=true/false). API zwraca listy, nie osobny endpoint szczegółów alarmu. Czas jest porównywany z dokładnością do milisekund również dla formatu PostgreSQL. Ponowne dostarczenie QoS 1 może stworzyć kilka zdarzeń o tym samym czasie: referencje muszą wskazywać jedno z nich, a alarm nadal musi być jeden. Test wykrywa nowy drugi alarm także w historii. Zestaw QA nie może mieć innego publikatora dla `flood_001` podczas testu.

Odpytywanie co 200 ms, timeout osobno na fazę, pojedyncze HTTP maksymalnie 3 s. Błąd HTTP kończy test, bez maskowania 401/403. Odpowiedź zawierająca 500 pozycji oznacza ryzyko obcięcia i wymaga świeżego QA. Przerwany smoke pozostawia własne rekordy do diagnostyki; nie ponawiaj go na otwartym alarmie. Wyłącz to QA i utwórz nowe.

## Flutter — potwierdzenie API a UI

Sprawdzono kod: `Alarm.fromJson` odczytuje powiązania i status, `isActive` obejmuje active/acknowledged, etykieta flood to Zalanie. Monitoring pobiera aktywne alarmy z API, szczegóły obsługują zalanie, a historia korzysta z danych backendu. Nie zmieniano Fluttera.

Do późniejszego odbioru ekranu utrzymaj ręczne QA i użyj instrukcji Flutter z [izolowanego demo](isolated-software-demo.md): Windows `--dart-define=VEDASENTIO_API_BASE_URL=http://127.0.0.1:18080`, Android z `adb reverse tcp:18080 tcp:18080`. Sam automatyczny smoke szybko rozwiązuje alarm. Do obejrzenia stanu aktywnego po zalogowaniu aplikacji, przed każdą publikacją sprawdź QA:

```powershell
Assert-FloodQaInstance $id $env:VEDASENTIO_API_BASE_URL $env:VEDASENTIO_TEST_MQTT_CONTAINER
./scripts/mqtt_test_event.ps1 -HomeId home_001 -DeviceId flood_001 -EventType flood_detected -ValueJson true
# Odśwież monitoring i otwórz szczegóły w aplikacji.
Assert-FloodQaInstance $id $env:VEDASENTIO_API_BASE_URL $env:VEDASENTIO_TEST_MQTT_CONTAINER
./scripts/mqtt_test_event.ps1 -HomeId home_001 -DeviceId flood_001 -EventType flood_cleared -ValueJson false
# Odśwież historię; po odbiorze uruchom stop dla $id.
```

**UI nie zostało odebrane.** Rozpoznanie urządzeń Flutter nie ukończyło się i zostało przerwane; nie instalowano emulatora. Lokalny `flutter pub get --offline` odtworzył zależności. `flutter test --no-pub`: 103/103 PASS. `flutter analyze --no-pub`: kod 1, jedna istniejąca uwaga info `prefer_interpolation_to_compose_strings` w `HomeDetailsScreen` (linia 742); bez zmian stylistycznych poza zakresem. Pierwsze próby bez zależności zakończyły się błędami środowiska, nie zostały uznane za zaliczone.

## Wykonane kontrole

- Pełny CMake/build Debug na Windows, CTest 4/4 i 36 istniejących kontroli QA: PASS.
- 21 scenariuszy logiki smoke oraz test rzeczywistego adaptera tablic odpowiedzi HTTP i składnia PowerShell: PASS. Transport jest w tych testach jawnie symulowany; nie stanowią pełnego E2E.
- Negatywne scenariusze obejmują brak JWT, 401/403, brak/nieaktywność urządzenia, active/acknowledged, niedostępny backend, obce QA, timeout, stare zdarzenie, obcy typ/urządzenie/ID/źródło/last_event/severity/resolution i drugi alarm. Przedwstępne błędy dają zero wywołań publikatora.
- **Rzeczywiste MQTT → PostgreSQL → JWT REST API: PASS.** Drzwi dały nowe eventy 1/2. Alarm zalania ID 1: source=3, last=3 → 4 → 5, active → resolved/sensor, zachowana historia. Pełna regresja alarmów: PASS.
- Rzeczywiste negatywne próby: brak JWT, błędny JWT/HTTP 401, obcy ID QA i błędny adres API odrzucone; historia zdarzeń przed/po identyczna. HTTP 403 i pozostałe błędne odpowiedzi sprawdzono w testach z symulowanym transportem.
- Własne kontenery/proces/sieć sprzątnięte. Konfiguracja, mounty i czasy startu wcześniejszych kontenerów identyczne. Próba zatrzymania obcego kontenera została odrzucona przez istniejący test z #62.
- Pierwsza próba wykryła zagnieżdżoną tablicę z Invoke-RestMethod; adapter teraz jawnie emituje wiersze i ma regresję. To poprawka narzędzia testowego, nie reguł alarmowych.
- Nie wykonano testu fizycznego ESP32, UI, FCM ani smoke SOS z #58. CI jest raportowane osobno w PR.
