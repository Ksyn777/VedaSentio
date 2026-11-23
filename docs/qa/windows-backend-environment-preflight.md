# Diagnostyka i uruchomienie backendu na Windows 11

Potrzebujesz Windows 11 x64, PowerShell 7 (`pwsh`), Git, CMake i Visual
Studio lub Build Tools z obciążeniem **Desktop development with C++**,
kompilatorem MSVC x64 i Windows SDK. CMake musi obsługiwać generator dla
zainstalowanego Visual Studio. Docker Desktop w trybie kontenerów Linux
jest potrzebny do odbioru z PostgreSQL i Mosquitto. Flutter jest opcjonalny.

## Sprawdzenie komputera

```powershell
Set-Location 'C:\Users\kamil\Desktop\Projekty\VedaSentio-Git'
.\scripts\check_windows_dev_environment.ps1
```

`PASS` potwierdza daną kontrolę, `WARN` wskazuje brak konfiguracji lub stan
do sprawdzenia przed odbiorem, a `FAIL` oznacza blokadę narzędzi lub
manifestu (kod wyjścia `1`). Zajęty port jest ostrzeżeniem, bo usługa
może już działać. Diagnostyka pokazuje wyłącznie nazwy brakujących
zmiennych. Sprawdzenie cache odczytuje toolchain, manifest i triplet bez
drukowania wartości z cache. Skrypt domyślnie nie łączy się z usługami
aplikacji. Opcja `-ProbeServices` odczytuje `GET /api/health` i próbuje
połączeń TCP z loopbackiem. Otwarty port nie potwierdza logowania,
tożsamości bazy ani gotowości do smoke testu.

## Przygotowanie vcpkg i kompilacja

Manifest ma już `builtin-baseline` równy
`4cb050be2cfa7a947cdd2dd1a70e24b17774c979`. Na tym komputerze w sesji
Codexa `VCPKG_ROOT` nie było ustawione. Checkout `C:\Users\kamil\vcpkg`
zawierał plik wykonywalny i toolchain, ale nie miał obiektu tego commita.
Dlatego konfiguracja kończyła się błędem odczytu
`versions/baseline.json` z przypiętej rewizji, choć plik istniał w
drzewie roboczym starego checkoutu.

Przygotuj osobny checkout z tym samym commitem co w manifeście. Poniższe
polecenia tworzą nowy katalog z unikalną nazwą, pobierają zależności
publiczne i ustawiają `VCPKG_ROOT` wyłącznie w bieżącej sesji.

```powershell
$repo = (Get-Location).Path
$pin = (Get-Content -Raw (Join-Path $repo 'vcpkg.json') | ConvertFrom-Json).'builtin-baseline'
$vcpkgPath = Join-Path $env:LOCALAPPDATA "VedaSentio-vcpkg-$([guid]::NewGuid().ToString('N'))"
git init $vcpkgPath
if ($LASTEXITCODE) { throw 'Nie mozna utworzyc checkoutu vcpkg.' }
git -C $vcpkgPath fetch --depth 1 https://github.com/microsoft/vcpkg.git $pin
if ($LASTEXITCODE) { throw 'Nie mozna pobrac baseline vcpkg.' }
git -C $vcpkgPath switch --detach FETCH_HEAD
if ($LASTEXITCODE) { throw 'Nie mozna przelaczyc checkoutu vcpkg.' }
git -C $vcpkgPath cat-file -t "${pin}:versions/baseline.json"
if ($LASTEXITCODE) { throw 'Brak pliku baseline w przypietym commicie.' }
& (Join-Path $vcpkgPath 'bootstrap-vcpkg.bat') -disableMetrics
if ($LASTEXITCODE) { throw 'Bootstrap vcpkg nie powiodl sie.' }
$env:VCPKG_ROOT = $vcpkgPath
.\scripts\check_windows_dev_environment.ps1
```

Zachowaj ścieżkę tego checkoutu do następnych sesji. Ustaw ją ponownie
przed konfiguracją lub diagnostyką. W nowym katalogu build polecenia
kompilacji wyglądają następująco:

```powershell
$repo = (Get-Location).Path
$build = Join-Path $repo 'backend/build'
if (Test-Path (Join-Path $build 'CMakeCache.txt')) {
    throw 'Build ma juz cache. Wybierz nowy katalog w $build lub uzyj swiezej kopii do odbioru.'
}
cmake -S backend -B $build -A x64 `
    "-DCMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" `
    "-DVCPKG_MANIFEST_DIR=$repo" -DVCPKG_TARGET_TRIPLET=x64-windows
if ($LASTEXITCODE) { throw 'Konfiguracja CMake nie powiodla sie.' }
cmake --build $build --config Debug --parallel 2
if ($LASTEXITCODE) { throw 'Kompilacja nie powiodla sie.' }
ctest --test-dir $build -C Debug --output-on-failure
if ($LASTEXITCODE) { throw 'CTest zglosil blad.' }
```

Przy świadomie wybranym innym katalogu sprawdź go przez
`-BuildDirectory $build`. Kolejne kompilacje tego samego, zgodnie
skonfigurowanego katalogu można wykonać przez samo `cmake --build`.
`create_dev_user.ps1` oczekuje binariów w `backend/build/Debug`, więc do
pełnego odbioru z tym skryptem użyj świeżej kopii repozytorium i tej ścieżki.

## Odbiór SOS na osobnych usługach

Backend łączy się z brokerem na `127.0.0.1:1883`, API zajmuje
`127.0.0.1:8080`, a publikator wykonuje polecenie w kontenerze o nazwie
`vedasentio-mqtt`. Na badanym hoście port 1883 i nazwa są już zajęte.
Pełny odbiór w tej sytuacji wykonaj na osobnym Windows z własnym
silnikiem Docker, na przykład w gotowej maszynie testowej. Sam inny
projekt Compose korzystający z tego samego silnika i hosta nie rozwiąże
konfliktu. Poniższe instrukcje nie wymagają zatrzymywania ani zmiany
istniejącej instalacji.

W świeżej kopii repozytorium na tym odizolowanym hoście pobierz gałąź
odbiorową PR #58 i zbuduj backend według poprzedniego bloku. Szczegóły
scenariusza znajdują się w [instrukcji PR #58](https://github.com/Ksyn777/VedaSentio/blob/test/29-sos-mqtt-api-smoke/docs/qa/software-sos-mqtt-api-smoke.md).

```powershell
git fetch origin test/29-sos-mqtt-api-smoke
if ($LASTEXITCODE) { throw 'Nie mozna pobrac galezi smoke SOS.' }
git switch --detach FETCH_HEAD
if ($LASTEXITCODE) { throw 'Nie mozna przelaczyc kopii testowej na kod PR #58.' }
```

W tej kopii, po kompilacji i potwierdzeniu, że terminal używa lokalnego
Docker Desktop (`docker context show`, `docker version`), utwórz świeżą
bazę z danymi w pamięci i testowy broker tylko na loopbackie. Ostatni
blok migracji kieruje polecenia do identyfikatora **nowo utworzonego**
kontenera bazy.

```powershell
$ErrorActionPreference = 'Stop'
$endpoint = docker context inspect --format '{{.Endpoints.docker.Host}}'
if ($LASTEXITCODE -or $endpoint -notlike 'npipe:////./pipe/*' -or $env:DOCKER_HOST) {
    throw 'Uzyj lokalnego kontekstu Docker Desktop, bez DOCKER_HOST w sesji.'
}
$engine = docker version --format '{{.Server.Os}}'
if ($LASTEXITCODE -or $engine -ne 'linux') { throw 'Uruchom lokalny Docker Desktop w trybie Linux.' }
$listeners = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
if ($listeners.Port | Where-Object { $_ -in 1883, 8080, 15433 }) {
    throw 'Port testowy zajety. Wykonaj odbior na osobnym Windows z wolnymi portami.'
}
$broker = docker ps -a --filter 'name=^/vedasentio-mqtt$' --format '{{.Names}}'
if ($LASTEXITCODE -or $broker) { throw 'Nazwa vedasentio-mqtt jest zajeta lub Docker nie odpowiada.' }

$testId = [guid]::NewGuid().ToString('N')
$testDir = Join-Path $env:TEMP "vedasentio-sos-$testId"
New-Item -ItemType Directory $testDir | Out-Null
$env:VEDASENTIO_DB_HOST = '127.0.0.1'
$env:VEDASENTIO_DB_PORT = '15433'
$env:VEDASENTIO_DB_NAME = 'vedasentio_sos_test'
$env:VEDASENTIO_DB_USER = 'vedasentio_sos_test'
$bytes = [byte[]]::new(24)
[Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$env:VEDASENTIO_DB_PASSWORD = [Convert]::ToBase64String($bytes)
$env:POSTGRES_DB = $env:VEDASENTIO_DB_NAME
$env:POSTGRES_USER = $env:VEDASENTIO_DB_USER
$env:POSTGRES_PASSWORD = $env:VEDASENTIO_DB_PASSWORD
$dbId = docker run -d --name "vedasentio-sos-db-$testId" `
    --tmpfs /var/lib/postgresql/data -p 127.0.0.1:15433:5432 `
    -e POSTGRES_DB -e POSTGRES_USER -e POSTGRES_PASSWORD postgres:17
if ($LASTEXITCODE -or $dbId -notmatch '^[0-9a-f]{64}$') { throw 'Nie utworzono testowej bazy.' }
Remove-Item Env:POSTGRES_PASSWORD

$env:VEDASENTIO_MQTT_USER = 'vedasentio_sos_test'
@'
listener 1883 0.0.0.0
allow_anonymous false
password_file /smoke/passwords
persistence false
'@ | Set-Content -Encoding ascii (Join-Path $testDir 'mosquitto.conf')
docker run --rm -it --user 1883:1883 --mount "type=bind,source=$testDir,target=/smoke" `
    eclipse-mosquitto:2 mosquitto_passwd -c /smoke/passwords $env:VEDASENTIO_MQTT_USER
if ($LASTEXITCODE) { throw 'Nie utworzono testowego pliku hasel Mosquitto.' }
$env:VEDASENTIO_MQTT_PASSWORD = Read-Host -MaskInput 'Wpisz to samo testowe haslo Mosquitto'
$brokerId = docker run -d --name vedasentio-mqtt --user 1883:1883 -p 127.0.0.1:1883:1883 `
    --mount "type=bind,source=$testDir,target=/smoke,readonly" `
    eclipse-mosquitto:2 mosquitto -c /smoke/mosquitto.conf
if ($LASTEXITCODE -or $brokerId -notmatch '^[0-9a-f]{64}$') { throw 'Nie uruchomiono testowego brokera.' }
```

Zaczekaj na gotowość serwera i uruchom ten blok **raz** dla świeżego
kontenera wskazanego przez `$dbId`. Wszystkie polecenia wykonuj w tej
samej sesji PowerShell.

```powershell
docker exec $dbId pg_isready -h 127.0.0.1 -U $env:VEDASENTIO_DB_USER -d $env:VEDASENTIO_DB_NAME
if ($LASTEXITCODE) { throw 'Testowy PostgreSQL jeszcze nie jest gotowy. Ponow sprawdzenie.' }
$files = @(Get-ChildItem .\database\0*_*.sql | Sort-Object Name)
$files += Get-Item .\database\dev_seed.sql
foreach ($file in $files) {
    Get-Content $file.FullName -Raw |
        docker exec -i $dbId psql -U $env:VEDASENTIO_DB_USER -d $env:VEDASENTIO_DB_NAME -v ON_ERROR_STOP=1
    if ($LASTEXITCODE) { throw "Blad pliku $($file.Name) w bazie testowej." }
}
foreach ($name in 'VEDASENTIO_DATA_ENCRYPTION_KEY_B64',
    'VEDASENTIO_LOOKUP_HMAC_KEY_B64', 'VEDASENTIO_JWT_SIGNING_KEY_B64') {
    $bytes = [byte[]]::new(32)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $value = [Convert]::ToBase64String($bytes)
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
}
Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS -ErrorAction SilentlyContinue
.\scripts\create_dev_user.ps1
$exe = (Resolve-Path .\backend\build\Debug\vedasentio_backend.exe).Path
$backendJob = Start-Job -ScriptBlock { param($exe) & $exe } -ArgumentList $exe
```

Po starcie backendu potwierdź `status = ok` oraz
`service = vedasentio-backend`. Jeśli API nie odpowiada, odczytaj log
procesu poleceniem `Receive-Job $backendJob -Keep`.

```powershell
Invoke-RestMethod http://127.0.0.1:8080/api/health -NoProxy -TimeoutSec 3
.\scripts\login_api_dev.ps1
.\scripts\smoke_sos_mqtt_api.ps1 -ConfirmIsolatedEnvironment -TimeoutSeconds 15
```

Po odbiorze możesz zatrzymać **tylko** uruchomiony job i kontenery, których
identyfikatory zachowałeś w tej sesji. Przy zatrzymaniu bazy testowej dane
w tmpfs znikną. Skrypt diagnostyczny sam nie uruchamia ani nie zatrzymuje
żadnej usługi.

## Najczęstsze błędy

| Objaw | Co sprawdzić |
| --- | --- |
| `VCPKG_ROOT` puste lub brak toolchain | Ustaw ścieżkę do przypiętego checkoutu z plikiem `vcpkg.exe`. |
| `git show ...:versions/baseline.json` kończy się błędem | Sprawdź dostępność obiektu commita w tym checkoutcie. Użyj osobnego checkoutu z powyższych poleceń. |
| CMake nie znajduje kompilatora lub pakietu | Sprawdź MSVC x64, Windows SDK, obsługę generatora i wybrany toolchain. Użyj nowego `-B` z manifestem z katalogu głównego i `x64-windows`. |
| API, MQTT lub PostgreSQL zajmują port | Ustal właściciela nasłuchu. Dla pełnego testu z zajętym 1883 użyj osobnego środowiska Windows. |
| `GET /api/health` działa, ale smoke zgłasza 401/403 | Zaloguj się w tej samej sesji do właściwego API i sprawdź przypisanie konta do `home_001`. |
| Smoke zgłasza otwarty alarm lub timeout | Sprawdź źródło poprzedniego alarmu, logi testowe i izolację publikatora. Użyj świeżego środowiska testowego. |
