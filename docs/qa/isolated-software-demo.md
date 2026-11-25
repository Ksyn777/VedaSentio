# Izolowana demonstracja programowa na Windows 11

Refs #61, #29, #59. To syntetyczne QA bez ESP32 i bez Firebase, nie test systemu medycznego.

## Wymagania i kompilacja

Windows 11, PowerShell 7, Docker Desktop z lokalnym silnikiem Linux, Git, Visual Studio C++ x64, CMake >=3.20. Otwórz **nowy terminal** w katalogu tej gałęzi. Nie wczytuj istniejącego `.env`. Skrypty nie potrzebują produkcyjnych sekretów i nie używają istniejącej bazy.

`vcpkg.json` przypina baseline. Użyj osobnego, krótkiego checkoutu vcpkg (np. `%LOCALAPPDATA%/vs-v`) zawierającego ten commit. Nie zmieniaj manifestu i nie resetuj istniejącego vcpkg. Szczegóły diagnostyki rozwija niezależny PR #60; jego lokalna poprawka krótkiej ścieżki pozostaje nietknięta.

```powershell
$env:VCPKG_ROOT = "$env:LOCALAPPDATA/vs-v" # własny checkout przypięty do baseline
cmake -S backend -B backend/build -A x64 "-DCMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-windows
if ($LASTEXITCODE) { throw 'CMake failed' }
cmake --build backend/build --config Debug --parallel 2
if ($LASTEXITCODE) { throw 'Build failed' }
ctest --test-dir backend/build -C Debug --output-on-failure
./scripts/test_isolated_qa.ps1 -BackendPath ./backend/build/Debug/vedasentio_backend.exe
```

Przy błędzie C1083 w libsodium skróć ścieżkę **osobnego** checkoutu vcpkg. Nie przenoś ani nie usuwaj użytkownikowi dotychczasowych plików. Istniejący cache binarny może przyspieszyć ponowne zbudowanie zależności.

## Pełny automatyczny odbiór

```powershell
./scripts/test_isolated_qa_integration.ps1 -ConfirmIsolatedEnvironment
```

Test uruchamia prawdziwe usługi, migracje i seed, tworzy fikcyjnego użytkownika, loguje go i uruchamia istniejący smoke drzwi w obu kierunkach. Sukces wymaga odczytania świeżych rekordów z autoryzowanego API. Uruchamia także istniejącą regresję alarmów na tej samej jednorazowej bazie. `finally` zatrzymuje wyłącznie własne QA; porównuje konfigurację, mounty i czasy startu wcześniejszych kontenerów. Żaden test nie wymaga zatrzymania obecnego brokera na 1883.

## Start do ręcznego odbioru

```powershell
./scripts/start_isolated_qa.ps1 -ConfirmIsolatedEnvironment
$id = $global:VEDASENTIO_QA_ID
Invoke-RestMethod "$env:VEDASENTIO_API_BASE_URL/api/health"
```

Domyślne osobne porty: DB `127.0.0.1:15433`, MQTT `127.0.0.1:28883`, API `127.0.0.1:18080`. Parametry `-DbPort`, `-MqttPort`, `-ApiPort` pozwalają jawnie wybrać inne porty. Zajęty port kończy start przed utworzeniem zasobów. Nie ma automatycznego przełączenia na działający broker. Brak skompilowanego backendu również kończy start bez tworzenia usług.

Każde QA otrzymuje losowy identyfikator, własną sieć `vsqa-<id>`, kontenery `vsqa-<id>-db` i `vsqa-<id>-mqtt`, etykietę właściciela, bazę `vsqa_<id>`, konto `qa_<id>` oraz nowe hasła i klucze. PostgreSQL 17 i wszystkie katalogi danych Mosquitto 2 używają **tmpfs**. Dane znikają po zatrzymaniu kontenera. Brak trwałych wolumenów i montowania katalogów repozytorium. Kontenery publikują porty tylko na loopback.

Start sprawdza lokalny named pipe Docker i odrzuca TCP/SSH oraz nadpisania `DOCKER_HOST`/TLS. Nie przełącza kontekstu. Przy ustawieniu tych nadpisań otwórz świeży terminal z lokalnym kontekstem; nie zmieniaj działających projektów.

Zmienne backendu ustawiane są jawnie w `ProcessStartInfo.Environment`, bez `Start-Job`. Firebase jest usunięte z konfiguracji dziecka niezależnie od konfiguracji terminala. Po sukcesie nowe zmienne QA są dostępne w tym samym terminalu do utworzenia użytkownika i publikacji. Używaj terminala wyłącznie do tego QA, utrzymuj go otwartym i uruchom stop przed jego zamknięciem. Surowe wyjście backendu jest opróżniane asynchronicznie w pamięci, bez zapisu logów z danymi. Nie loguj środowiska ani pełnego `docker inspect` — Docker przechowuje hasło testowego PostgreSQL w konfiguracji kontenera, dostępnej administratorowi lokalnego silnika. `mosquitto_passwd` i istniejący publikator przekazują hasło krótkotrwale jako argument lokalnego procesu.

Stan `%LOCALAPPDATA%/VedaSentio/qa/<id>/state.json` zawiera identyfikatory zasobów, PID, ścieżkę i czas utworzenia procesu, **bez sekretów**. Nie edytuj go. Nie jest magazynem poświadczeń i nie umożliwia wznowienia bazy po restarcie.

## Użytkownik testowy i drzwi

W terminalu, który uruchomił QA:

```powershell
./scripts/create_dev_user.ps1
# Podaj fikcyjne dane, home_001 i rolę owner lub caregiver.
./scripts/login_api_dev.ps1
./scripts/smoke_door_mqtt_api.ps1 -State opened
./scripts/smoke_door_mqtt_api.ps1 -State closed
```

Skrypty przyjmują `VEDASENTIO_API_BASE_URL` i `VEDASENTIO_TEST_MQTT_CONTAINER` ze środowiska ustawionego przez start. Można je też przekazać jawnie jako `-ApiBaseUrl` oraz `-MqttContainer`. Dostępne są tylko HTTP loopback bez credentials, ścieżki, query i fragmentu; przekierowania HTTP są zablokowane. Domyślne wartości poza QA pozostają `http://127.0.0.1:8080` i `vedasentio-mqtt`. Publikator łączy się **wewnątrz wybranego kontenera** z jego portem 1883; mapowanie hosta 28883 jest dla backendu.

Backend akceptuje `VEDASENTIO_MQTT_PORT` i `VEDASENTIO_API_PORT` w zakresie 1–65535. Brak zmiennych zachowuje 1883/8080; ustawiona pusta wartość, znaki, białe znaki, minus i przekroczenie zakresu kończą proces przed utworzeniem usług. Host API i brokera pozostaje `127.0.0.1`. Stały identyfikator klienta MQTT nie koliduje między osobnymi brokerami. Semantyka danych, JWT, ról i alarmów nie została zmieniona.

## SOS i PR #58

PR #58 pozostaje niezależny i niescalony; **nie zgłaszamy pełnego smoke SOS PASS**. Po jego odbiorze i scaleniu podłącz `smoke_sos_mqtt_api.ps1` analogicznie do smoke drzwi: wczytaj `qa_local_common.ps1`, pobierz bazowy adres przez `Get-QaApiBaseUrl`, zbuduj URL-e przez `$ApiBaseUrl`, zablokuj przekierowania. Wspólny publikator już honoruje wybrany kontener. Nie kopiuj kodu SOS do tego PR. Po dostosowaniu w tym samym terminalu QA:

```powershell
# Dopiero po scaleniu i opisanym dostosowaniu PR #58:
./scripts/login_api_dev.ps1
./scripts/smoke_sos_mqtt_api.ps1 -ConfirmIsolatedEnvironment -TimeoutSeconds 15
```

## Flutter

Istniejące `mobile/lib/config/app_config.dart` czyta `String.fromEnvironment`. Kod Fluttera pozostaje bez zmian.

Windows desktop (jeśli SDK i platforma desktop są dostępne):

```powershell
cd mobile
flutter run -d windows --dart-define=VEDASENTIO_API_BASE_URL=http://127.0.0.1:18080
```

Android: `127.0.0.1` wskazuje emulator, a `10.0.2.2` jest specjalnym aliasem hosta emulatora. Dla API ograniczonego do loopback użyj jawnego tunelu ADB zamiast wystawiać serwer publicznie:

```powershell
adb devices
adb -s emulator-5554 reverse tcp:18080 tcp:18080
cd mobile
flutter run -d emulator-5554 --dart-define=VEDASENTIO_API_BASE_URL=http://127.0.0.1:18080
# Po odbiorze:
adb -s emulator-5554 reverse --remove tcp:18080
```

Zastąp ID identyfikatorem własnego emulatora. Nie potwierdzono UI, emulatora ani powiadomień FCM w tym zadaniu.

## Stop i diagnostyka

```powershell
./scripts/stop_isolated_qa.ps1 -Id $id -ConfirmStop
```

Stop najpierw sprawdza **wszystkie** tożsamości: pełne ID, nazwy i etykiety kontenerów, etykietę sieci i jej członków oraz PID, executable, czas utworzenia i marker procesu. Przy niezgodności przerywa przed zatrzymaniem czegokolwiek. Bez `-ConfirmStop` niczego nie zatrzymuje. Stan bez sekretów pozostaje dla diagnostyki; ponowne wywołanie rozpoznaje zasoby już nieobecne. Nie używa prune ani `compose down -v`.

Jeśli start przerwano po utworzeniu zasobów, użyj ID wypisanego w komunikacie błędu do tego samego polecenia stop. Nie uruchamiaj ręcznie migracji na innej bazie. Przy błędzie backendu sprawdź, czy wszystkie DLL z builda są obok exe, uruchom testy konfiguracji i sprawdź dostępność wskazanych portów. Surowe błędy usług są celowo tłumione; nie wypisuj sekretów, aby je diagnozować. Test nie jest transakcją: nieudane QA sprząta się przez jego ID, a nie przez usuwanie całego Dockera.

## Rzeczywiście sprawdzone

Na Windows 11: CMake + pełny build Debug, CTest 4/4 (17 asercji konfiguracji w nowym teście), 36 kontroli QA, parser PowerShell dla wszystkich skryptów. PostgreSQL 17 z migracjami i seedem, uwierzytelniony Mosquitto 2, nowy backend i JWT, otwarcie/zamknięcie drzwi odczytane w API jako nowe rekordy, pełna istniejąca regresja alarmów i kryptografia. Negatywne próby zajętego portu oraz zatrzymania cudzego kontenera. Kontrola stanu bez sekretów i porównanie konfiguracji/mountów/czasów startu istniejących kontenerów.

W pierwszych próbach naprawiono konwersję daty JSON w kontroli PID, niestabilną kolejność mountów w porównaniu inwentarza i anonimowe wolumeny obrazu Mosquitto. Poprawione rozwiązanie używa ticks, sortowania i tmpfs. Pozostałości prób usunięto po identyfikacji w zdarzeniach Docker. Nie wykonano smoke SOS z PR #58, testu ESP32, UI ani FCM.
