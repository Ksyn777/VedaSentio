param(
    [switch]$ProbeServices,
    [string]$BuildDirectory = 'backend/build'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$failures = [Collections.Generic.List[string]]::new()
$repoRoot = Split-Path -Parent $PSScriptRoot

function Report($Level, $Check, $Message) {
    Write-Host "[$Level] $Check - $Message"
    if ($Level -eq 'FAIL') { $failures.Add($Check) }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Report FAIL 'PowerShell' 'Otworz pwsh (PowerShell 7), a nastepnie uruchom ten skrypt.'
    exit 1
}
if (-not $IsWindows) {
    Report FAIL 'System' 'Uruchom skrypt w PowerShell 7 na Windows, poza WSL.'
    exit 1
}
Report PASS 'PowerShell' "PowerShell $($PSVersionTable.PSVersion) na Windows."

$git = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($git) { Report PASS 'Git' 'Git jest dostepny.' }
else { Report FAIL 'Git' 'Zainstaluj: winget install --id Git.Git -e. Otworz nowy terminal.' }

$cmake = Get-Command cmake.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cmake) {
    $versionLines = @(& $cmake.Source --version 2>$null)
    if ($LASTEXITCODE -eq 0 -and $versionLines[0] -match '^cmake version ([\d.]+)' -and
        [version]$Matches[1] -ge [version]'3.20') {
        Report PASS 'CMake' "Wersja $($Matches[1]) osiagnela minimum projektu."
    }
    else { Report FAIL 'CMake' 'Wymagany CMake >= 3.20 i generator dla zainstalowanego Visual Studio.' }
}
else { Report FAIL 'CMake' 'Zainstaluj: winget install --id Kitware.CMake -e. Otworz nowy terminal.' }

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$msvc = @()
if (Test-Path -LiteralPath $vswhere -PathType Leaf) {
    $msvc = @(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -find 'VC\Tools\MSVC\**\bin\Hostx64\x64\cl.exe' 2>$null |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
}
if ($msvc.Count -gt 0) { Report PASS 'MSVC x64' 'vswhere znalazl zainstalowany kompilator x64.' }
else {
    Report FAIL 'MSVC x64' 'W Visual Studio Installer dodaj Desktop development with C++, MSVC x64/x86 i Windows SDK.'
}

$manifest = $null
try {
    $manifest = Get-Content -LiteralPath (Join-Path $repoRoot 'vcpkg.json') -Raw |
        ConvertFrom-Json -AsHashtable
    if ($manifest['builtin-baseline'] -notmatch '\A[0-9a-fA-F]{40}\z' -or
        @($manifest['dependencies']).Count -eq 0 -or -not $manifest['dependencies']) {
        throw 'Invalid manifest'
    }
    Report PASS 'Manifest vcpkg' 'Odczytano vcpkg.json z katalogu glownego i przypiety builtin-baseline.'
}
catch {
    $manifest = $null
    Report FAIL 'Manifest vcpkg' 'Sprawdz vcpkg.json z origin/master, w tym builtin-baseline i dependencies.'
}

$vcpkgRoot = $env:VCPKG_ROOT
$toolchain = $null
if ([string]::IsNullOrWhiteSpace($vcpkgRoot)) {
    Report FAIL 'VCPKG_ROOT' 'Po przygotowaniu checkoutu ustaw w tej sesji: $env:VCPKG_ROOT = $vcpkgPath'
}
elseif (-not [IO.Path]::IsPathFullyQualified($vcpkgRoot) -or
    -not (Test-Path -LiteralPath $vcpkgRoot -PathType Container)) {
    Report FAIL 'VCPKG_ROOT' 'Ustaw bezwzgledna sciezke do istniejacego katalogu vcpkg.'
}
else {
    $toolchain = Join-Path $vcpkgRoot 'scripts/buildsystems/vcpkg.cmake'
    if ((Test-Path -LiteralPath $toolchain -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $vcpkgRoot 'vcpkg.exe') -PathType Leaf)) {
        Report PASS 'VCPKG_ROOT' 'Znaleziono vcpkg.exe i toolchain CMake.'
    }
    else {
        Report FAIL 'VCPKG_ROOT' 'Sprawdz katalog checkoutu i uruchom bootstrap-vcpkg.bat -disableMetrics w osobnym checkoutcie.'
    }

    if ($git -and $manifest) {
        $pin = $manifest['builtin-baseline']
        & $git.Source -C $vcpkgRoot cat-file -e "${pin}^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Report FAIL 'Baseline vcpkg' "Brak dostepnego commita $pin. Przygotuj osobny checkout wedlug instrukcji."
        }
        else {
            try {
                $raw = & $git.Source -C $vcpkgRoot show "${pin}:versions/baseline.json" 2>$null
                if ($LASTEXITCODE -ne 0) { throw 'Missing baseline data' }
                $baseline = ($raw -join "`n") | ConvertFrom-Json -AsHashtable
                foreach ($dep in $manifest['dependencies']) {
                    $name = if ($dep -is [string]) { $dep } else { $dep['name'] }
                    if (-not $name -or -not $baseline['default'].ContainsKey($name)) {
                        throw 'Missing registry entry'
                    }
                }
                Report PASS 'Baseline vcpkg' 'Commit, versions/baseline.json i wpisy zaleznosci manifestu sa dostepne.'
                $checkoutCommit = & $git.Source -C $vcpkgRoot rev-parse HEAD 2>$null
                if ($LASTEXITCODE -ne 0 -or $checkoutCommit -ne $pin) {
                    Report WARN 'Checkout vcpkg' 'HEAD rozni sie od baseline. Dla zgodnosci z CI przygotuj osobny checkout tego commita.'
                }
            }
            catch {
                Report FAIL 'Baseline vcpkg' 'Brak poprawnego pliku baseline lub wpisow zaleznosci. Uzyj osobnego checkoutu przypietego w instrukcji.'
            }
        }
    }
}

$cachePath = Join-Path ([IO.Path]::GetFullPath($BuildDirectory, $repoRoot)) 'CMakeCache.txt'
if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
    try {
        $cache = @{}
        foreach ($line in Get-Content -LiteralPath $cachePath) {
            if ($line -match '^(CMAKE_TOOLCHAIN_FILE|VCPKG_MANIFEST_DIR|VCPKG_TARGET_TRIPLET):[^=]+=(.*)$') {
                $cache[$Matches[1]] = $Matches[2]
            }
        }
        if ($toolchain -and $cache['CMAKE_TOOLCHAIN_FILE'] -and $cache['VCPKG_MANIFEST_DIR'] -and
            [IO.Path]::GetFullPath($cache['CMAKE_TOOLCHAIN_FILE']) -eq [IO.Path]::GetFullPath($toolchain) -and
            [IO.Path]::GetFullPath($cache['VCPKG_MANIFEST_DIR']) -eq $repoRoot -and
            $cache['VCPKG_TARGET_TRIPLET'] -eq 'x64-windows') {
            Report PASS 'Cache CMake' 'Toolchain, manifest i triplet odpowiadaja tej konfiguracji.'
        }
        else { Report WARN 'Cache CMake' 'Uzyj nowego katalogu -B z toolchain i triplet x64-windows. Zachowaj obecny build.' }
    }
    catch { Report WARN 'Cache CMake' 'Nie mozna sprawdzic cache. Skonfiguruj osobny katalog -B.' }
}
else { Report WARN 'Cache CMake' 'Brak CMakeCache.txt. Uzyj polecenia cmake -S backend -B z instrukcji.' }

$docker = Get-Command docker.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($docker) {
    & $docker.Source compose version *> $null
    if ($LASTEXITCODE -eq 0) { Report PASS 'Docker Compose' 'Polecenie docker compose jest dostepne.' }
    else { Report WARN 'Docker Compose' 'Sprawdz instalacje Compose w Docker Desktop.' }

    $endpoint = & $docker.Source context inspect --format '{{.Endpoints.docker.Host}}' 2>$null
    if ($LASTEXITCODE -ne 0 -or $endpoint -notlike 'npipe:////./pipe/*' -or
        ($env:DOCKER_HOST -and $env:DOCKER_HOST -notlike 'npipe:////./pipe/*')) {
        Report WARN 'Docker Desktop' 'Wybierz lokalny kontekst Docker Desktop (docker context use desktop-linux).'
    }
    else {
        $engineOs = & $docker.Source version --format '{{.Server.Os}}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $engineOs -eq 'linux') {
            Report PASS 'Docker Desktop' 'Lokalny silnik kontenerow Linux odpowiada.'
        }
        else { Report WARN 'Docker Desktop' 'Uruchom Docker Desktop w trybie kontenerow Linux i sprawdz docker version.' }
    }
}
else { Report WARN 'Docker Desktop' 'Zainstaluj Docker Desktop do testow PostgreSQL i MQTT.' }

$required = @(
    'VEDASENTIO_DB_HOST', 'VEDASENTIO_DB_PORT', 'VEDASENTIO_DB_NAME',
    'VEDASENTIO_DB_USER', 'VEDASENTIO_DB_PASSWORD', 'VEDASENTIO_MQTT_USER',
    'VEDASENTIO_MQTT_PASSWORD', 'VEDASENTIO_DATA_ENCRYPTION_KEY_B64',
    'VEDASENTIO_LOOKUP_HMAC_KEY_B64', 'VEDASENTIO_JWT_SIGNING_KEY_B64'
)
$missing = @($required | Where-Object {
    $value = [Environment]::GetEnvironmentVariable($_, 'Process')
    [string]::IsNullOrWhiteSpace($value) -or $value -eq 'CHANGE_ME'
})
if ($missing.Count) {
    Report WARN 'Konfiguracja backendu' "Ustaw w sesji wymagane zmienne wedlug instrukcji. Brak lub placeholder: $($missing -join ', ')."
}
else { Report PASS 'Konfiguracja backendu' 'Wymagane zmienne sa obecne w sesji.' }
if ($env:GOOGLE_APPLICATION_CREDENTIALS) {
    Report WARN 'Sesja testowa' 'Przed startem backendu do smoke SOS usun GOOGLE_APPLICATION_CREDENTIALS z sesji.'
}

$ports = [ordered]@{ API = 8080; PostgreSQL = 5433; Mosquitto = 1883 }
$dbPort = 0
if ([int]::TryParse($env:VEDASENTIO_DB_PORT, [ref]$dbPort) -and $dbPort -ge 1 -and $dbPort -le 65535) {
    $ports.PostgreSQL = $dbPort
}
elseif ($env:VEDASENTIO_DB_PORT) {
    Report WARN 'Port PostgreSQL' 'VEDASENTIO_DB_PORT musi byc liczba 1-65535. Sprawdzam domyslny port 5433.'
}
if ($env:VEDASENTIO_DB_HOST -and $env:VEDASENTIO_DB_HOST -notin @('127.0.0.1', 'localhost', '::1')) {
    Report WARN 'Host PostgreSQL' 'Backend wskazuje host poza loopback. Do smoke ustaw izolowana baze na 127.0.0.1.'
}
try {
    $listeners = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
    foreach ($service in $ports.Keys) {
        $port = $ports[$service]
        if ($port -in $listeners.Port) {
            Report WARN "$service TCP $port" 'Port zajety. Potwierdz wlasciciela nasluchu przed startem uslug testowych.'
        }
        else { Report PASS "$service TCP $port" 'Nie wykryto nasluchu TCP.' }
    }
}
catch { Report WARN 'Porty' 'Nie mozna odczytac nasluchow TCP. Sprawdz Get-NetTCPConnection -State Listen.' }

if ($ProbeServices) {
    try {
        $health = Invoke-RestMethod 'http://127.0.0.1:8080/api/health' -NoProxy -MaximumRedirection 0 -TimeoutSec 3
        if ($health.status -cne 'ok' -or $health.service -cne 'vedasentio-backend') { throw 'Unexpected response' }
        Report PASS 'API health' 'Lokalny backend VedaSentio zwrocil status ok.'
    }
    catch { Report WARN 'API health' 'Brak oczekiwanej odpowiedzi z http://127.0.0.1:8080/api/health.' }

    foreach ($service in 'PostgreSQL', 'Mosquitto') {
        $port = $ports[$service]
        $socket = [Net.Sockets.TcpClient]::new()
        try {
            $task = $socket.ConnectAsync('127.0.0.1', $port)
            if (-not $task.Wait(1000) -or -not $socket.Connected) { throw 'TCP unavailable' }
            Report PASS "$service TCP" "Loopback odpowiada na porcie $port. Sprawdzono tylko polaczenie TCP."
        }
        catch { Report WARN "$service TCP" "Loopback nie odpowiada na porcie $port. Sprawdz izolowana usluge." }
        finally { $socket.Dispose() }
    }
}

if (Get-Command flutter -ErrorAction SilentlyContinue) { Report PASS 'Flutter' 'Opcjonalne polecenie jest dostepne.' }
else { Report WARN 'Flutter' 'Opcjonalny do odbioru aplikacji mobilnej.' }

if ($failures.Count) { exit 1 }
exit 0
