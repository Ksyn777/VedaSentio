# VedaSentio

**VedaSentio** to prototypowy system IoT wspomagający opiekę nad osobą starszą lub wymagającą nadzoru. Zdarzenia z czujników trafiają przez MQTT do backendu C++20 i PostgreSQL, a aplikacja Flutter udostępnia monitoring, aktywność i alarmy. To **projekt inżynierski**, a nie certyfikowany system alarmowy, wyrób medyczny ani zamiennik kontaktu z opiekunem i służbami ratunkowymi.

> **Stan na 23.11.2026:** `master` zawiera już poprawki monitoringu i historii Fluttera, rotację tokenów FCM oraz testowany parser odpowiedzi `UNREGISTERED` (PR #47–#50). Wyrejestrowanie tokena po logout jest przygotowane osobno w PR #52 i **nie należy traktować go jako wdrożonego**. Ten przewodnik opisuje aktualne pliki i komendy; część scenariuszy nadal wymaga lokalnego odbioru.

## Architektura

```text
ESP32 / testowy publikator
  -> Mosquitto MQTT (vedasentio/{home_id}/{device_id}/event)
  -> backend C++20 (Paho MQTT -> PostgreSQL -> reguły alarmów)
  -> lokalne HTTP REST API (JWT + role owner/caregiver/viewer)
  -> Flutter (monitoring, historia i potwierdzanie alarmów)
                              \-> opcjonalnie FCM HTTP v1 -> telefon
```

[Diagram, kontrakt MQTT, format JSON i lista zdarzeń](docs/architecture-mqtt.md).

| Katalog | Zawartość |
| --- | --- |
| `backend/` | C++20, odbieranie MQTT, API, reguły alarmów, kryptografia i push |
| `database/` | migracje 001–008 i lokalny seed testowy |
| `infrastructure/` | Docker Compose PostgreSQL 17 i Mosquitto 2 |
| `mobile/` | aplikacja Flutter oraz testy |
| `firmware/door_contact_esp32/` | przykładowe firmware drzwi z PlatformIO |
| `scripts/` | lokalne skrypty PowerShell, testowe eventy, logowanie i sekrety |
| `docs/` | dokumentacja techniczna, backlog, QA i kontekst pracy |

## Szybki start na Windows — tylko środowisko lokalne

Wymagane: **Git, PowerShell, Docker Desktop**, Visual Studio z narzędziami C++ i CMake, vcpkg oraz Flutter SDK (dla aplikacji mobilnej); do testów Androida także emulator lub telefon z `adb`. Nie jest potrzebny fizyczny ESP32. Komendy uruchamiaj z **katalogu głównego repozytorium**, w osobnej kopii developerskiej — nie na komputerze produkcyjnym.

### 1. Pobierz repozytorium i ustaw lokalną konfigurację

```powershell
git clone https://github.com/Ksyn777/VedaSentio.git
cd VedaSentio
Copy-Item .env.example .env
```

Edytuj `.env`: ustaw **unikalne, lokalne** hasła PostgreSQL i MQTT zamiast `CHANGE_ME`. `.env` jest ignorowany przez Git i nie wolno go publikować. W PowerShell można wczytać proste wpisy `KLUCZ=wartość` z tego wzorca do bieżącego procesu (skrypt nie drukuje wartości):

```powershell
Get-Content .env | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*=' } | ForEach-Object {
    $name, $value = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}
.\scripts\setup_dev_crypto_secrets.ps1
```

Skrypt `setup_dev_crypto_secrets.ps1` tworzy lub odczytuje **lokalne** klucze DPAPI poza repozytorium. Nie stosuj przełącznika `-ForceRotate` przy istniejących danych — rotacja klucza bez migracji uniemożliwi odczyt wcześniej zaszyfrowanych pól. Backend sam **nie wczytuje** pliku `.env`: potrzebuje tych zmiennych w środowisku procesu. Przy kolejnym otwarciu terminala uruchom też `.\scripts\load_dev_crypto_secrets.ps1`.

### 2. PostgreSQL i Mosquitto

```powershell
docker compose --env-file .env -f infrastructure/docker-compose.yml up -d postgres
```

Przed startem brokera utwórz lokalny plik haseł Mosquitto (przykład dla **pierwszej konfiguracji**, nie uruchamiaj `-c` ponownie na istniejącym pliku, bo go zastąpi). Po wywołaniu polecenia hasło wpisujesz interaktywnie, bez umieszczania go w historii poleceń:

```powershell
docker run --rm -it -v "$((Resolve-Path .\infrastructure\mosquitto\config).Path):/mosquitto/config" eclipse-mosquitto:2 mosquitto_passwd -c /mosquitto/config/passwords vedasentio_backend
docker compose --env-file .env -f infrastructure/docker-compose.yml up -d mosquitto
docker compose --env-file .env -f infrastructure/docker-compose.yml ps
```

Hasło w Mosquitto musi odpowiadać `VEDASENTIO_MQTT_PASSWORD`, a użytkownik `VEDASENTIO_MQTT_USER`. Nie udostępniaj pliku `infrastructure/mosquitto/config/passwords`.

**Porty na obecnej konfiguracji:** PostgreSQL `127.0.0.1:5433`, API `127.0.0.1:8080`, Mosquitto `1883`. Broker nasłuchuje na interfejsach hosta (`1883:1883`), ma hasło, ale **nie ma skonfigurowanego TLS**: ogranicz dostęp zaporą do zaufanej sieci, nie przekierowuj tego portu do Internetu. HTTP API jest przeznaczone wyłącznie do lokalnego developmentu.

### 3. Baza danych — tylko nowa, pusta baza testowa

Migracje są zwykłymi plikami SQL, nie automatycznym runnerem migracji. Na **świeżej** bazie wykonaj je rosnąco; `001` nie jest bezpieczne do bezwarunkowego uruchamiania drugi raz. Nie uruchamiaj tego bloku na istniejącej bazie bez kopii zapasowej.

```powershell
Get-ChildItem .\database\0*_*.sql | Sort-Object Name | ForEach-Object {
    Write-Host "Migration: $($_.Name)"
    Get-Content $_.FullName -Raw | docker exec -i vedasentio-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) { throw "Migration failed: $($_.Name)" }
}
Get-Content .\database\dev_seed.sql -Raw | docker exec -i vedasentio-postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1
if ($LASTEXITCODE -ne 0) { throw "Development seed failed" }
```

Seed wstawia wyłącznie testowy dom `home_001` i urządzenia `door_001` oraz `sos_001`. Sztuczne dane nie są odczytami fizycznych czujników.

### 4. Zbuduj i uruchom backend C++

Przykład PowerShell przy skonfigurowanym `VCPKG_ROOT` (wymagane biblioteki są zadeklarowane w `vcpkg.json`):

```powershell
cmake -S backend -B backend/build "-DCMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-windows
cmake --build backend/build --config Debug --parallel 2
.\backend\build\Debug\vedasentio_backend.exe
```

Backend korzysta z tych samych zmiennych środowiska, które ustawiono w kroku 1. Pracuje w terminalu, do chwili jego zatrzymania. Gdy API i baza działają:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/api/health
```

Użytkownika testowego (rola `owner` lub `caregiver`) utworzysz po seedzie za pomocą `.\scripts\create_dev_user.ps1`. Potem `.\scripts\login_api_dev.ps1` uzyska lokalny JWT bez drukowania hasła i tokena. Dodatkowe informacje: [autoryzacja API](docs/api_authentication.md).

### 5. Symuluj odczyt bez ESP32

W **drugim terminalu**, z ustawionym hasłem/użytkownikiem MQTT, wyślij testowy event:

```powershell
.\scripts\mqtt_test_door_contact.ps1 -State opened
.\scripts\mqtt_test_door_contact.ps1 -State closed
.\scripts\mqtt_test_event.ps1 -HomeId home_001 -DeviceId sos_001 -EventType sos_pressed -ValueJson true
```

Są to **syntetyczne** publikacje MQTT. Skrypty korzystają z kontenera `vedasentio-mqtt`; backend musi działać i mieć zapisane urządzenia. Możesz następnie sprawdzić zdarzenia i alarmy przez autoryzowane API. Brak poświadczeń Firebase nie zatrzymuje backendu ani zapisu alarmów — wyłącza tylko automatyczną wysyłkę powiadomień.

### 6. Flutter (opcjonalnie do testu ekranu)

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
cd ..
.\scripts\flutter_android_reverse.ps1
cd mobile
flutter run --dart-define=VEDASENTIO_API_BASE_URL=http://127.0.0.1:8080
```

Tunel `adb reverse` jest konieczny przy testowaniu Androida przez USB/emulator i lokalnym API działającym na Windows `127.0.0.1`. Na innym urządzeniu i w iOS sposób łączności wymaga osobnej, bezpiecznej konfiguracji. Realny FCM wymaga później testowego telefonu i lokalnej konfiguracji Firebase — same testy Flutter nie dowodzą dostarczenia push.

### 7. Firmware (kompilacja bez sprzętu)

```powershell
Copy-Item firmware/door_contact_esp32/include/secrets.example.h firmware/door_contact_esp32/include/secrets.h
pio run -d firmware/door_contact_esp32
```

Nie wysyłaj firmware na płytkę na obecnym etapie. `secrets.h` jest ignorowany przez Git; wartości Wi-Fi/MQTT uzupełnia się tylko lokalnie. Testy połączenia z prawdziwym ESP32 i kalibracja czujników będą **ostatnim etapem projektu**.

## Bezpieczeństwo i odbiór

- Nigdy nie commituj `.env`, `secrets.h`, kluczy JWT, plików Firebase czy tokenów FCM.
- Nie udostępniaj HTTP/MQTT/PostgreSQL publicznie; przed prawdziwym wdrożeniem wymagane są m.in. TLS, kontrola dostępu, audyt i przegląd bezpieczeństwa.
- GitHub Actions weryfikuje kompilację C++/ESP32 i analizę/testy Fluttera; **nie potwierdza** montażu urządzeń, rzeczywistego FCM ani bezpieczeństwa osoby monitorowanej.
- Więcej: [konfiguracja](docs/development/CONFIGURATION.md), [CI](docs/development/CI.md), [backlog](docs/backlog/ROADMAP.md) i [workflow zmian](docs/backlog/WORKFLOW.md).
