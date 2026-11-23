#Requires -Version 7.0
param(
    [switch]$ConfirmIsolatedEnvironment,

    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 15
)

$ErrorActionPreference = 'Stop'
$homeId = 'home_001'
$deviceId = 'sos_001'
$api = 'http://127.0.0.1:8080/api'
$homeApi = "$api/homes/$homeId"
$publisher = Join-Path $PSScriptRoot 'mqtt_test_event.ps1'

function Read-SmokeApi($Url, [int]$RequestTimeout = 5) {
    try {
        Invoke-RestMethod -Uri $Url -Headers $headers -NoProxy -MaximumRedirection 0 -TimeoutSec $RequestTimeout
    }
    catch {
        # Do not print request headers, exception dumps or response bodies.
        $status = $_.Exception.Response.StatusCode
        if ($null -ne $status) {
            throw "API zwrocilo HTTP $([int]$status). Sprawdz sesje i dostep do domu."
        }
        throw 'Lokalne API nie odpowiada lub zwrocilo niepoprawna odpowiedz.'
    }
}

function Read-OpenSos([int]$RequestTimeout = 5) {
    $alarms = Read-SmokeApi "$homeApi/alarms?active=true&limit=500" $RequestTimeout
    if (@($alarms | Where-Object { $null -ne $_ }).Count -ge 500) {
        throw 'Lista otwartych alarmow osiagnela limit API. Nie mozna bezpiecznie sprawdzic SOS.'
    }
    $alarms | Where-Object {
        $_.home_id -ceq $homeId -and $_.device_id -ceq $deviceId -and $_.alarm_type -ceq 'sos'
    }
}

function Find-SmokeEvent($Events, [long]$BeforeId, $EventType, [bool]$Value, [long]$TimestampMs) {
    foreach ($event in $Events) {
        if ([long]$event.id -le $BeforeId -or $event.home_id -cne $homeId -or
            $event.device_id -cne $deviceId -or $event.event_type -cne $EventType -or
            $event.value -isnot [bool] -or $event.value -ne $Value) {
            continue
        }
        $time = [DateTimeOffset]::MinValue
        if ($event.device_timestamp -is [DateTime] -or $event.device_timestamp -is [DateTimeOffset]) {
            $time = [DateTimeOffset]$event.device_timestamp
        }
        elseif (-not [DateTimeOffset]::TryParse([string]$event.device_timestamp,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$time)) {
            continue
        }
        if ($time.ToUnixTimeMilliseconds() -eq $TimestampMs) {
            $event
        }
    }
}

function Invoke-SosStep($EventType, [bool]$Value, [long]$TimestampMs, [long]$AlarmId,
    [long]$SourceId, [long]$PreviousEventId, $ExpectedStatus) {
    $existingEvents = Read-SmokeApi "$homeApi/events?limit=500"
    [long]$beforeId = ($existingEvents | Measure-Object -Property id -Maximum).Maximum
    $open = @(Read-OpenSos)
    if ($AlarmId -eq 0) {
        if ($open.Count -ne 0) {
            throw "Istnieje otwarty alarm SOS dla $homeId/$deviceId. Nie opublikowano zdarzenia."
        }
    }
    elseif ($open.Count -ne 1 -or $open[0].id -ne $AlarmId -or
        $open[0].status -cne 'active' -or $open[0].source_event_id -ne $SourceId -or
        $open[0].last_event_id -ne $PreviousEventId) {
        throw 'Stan alarmu zmienil sie poza testem. Wstrzymano kolejna publikacje.'
    }

    $timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($TimestampMs).ToString(
        "yyyy-MM-ddTHH:mm:ss.fff'Z'", [Globalization.CultureInfo]::InvariantCulture)
    $valueJson = if ($Value) { 'true' } else { 'false' }
    & $publisher -EventType $EventType -ValueJson $valueJson -HomeId $homeId -DeviceId $deviceId -TimestampUtc $timestamp | Out-Host

    $timer = [Diagnostics.Stopwatch]::StartNew()
    $foundEvent = $false
    while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $requestTimeout = [int][Math]::Ceiling([Math]::Min(5, $TimeoutSeconds - $timer.Elapsed.TotalSeconds))
        if ($requestTimeout -lt 1) { break }
        $events = Read-SmokeApi "$homeApi/events?limit=500" $requestTimeout
        $matchingEvents = @(Find-SmokeEvent $events $beforeId $EventType $Value $TimestampMs)
        if ($matchingEvents.Count -gt 0) {
            $foundEvent = $true
            $requestTimeout = [int][Math]::Ceiling([Math]::Min(5, $TimeoutSeconds - $timer.Elapsed.TotalSeconds))
            if ($requestTimeout -lt 1) { break }
            $open = @(Read-OpenSos $requestTimeout)
            if ($ExpectedStatus -eq 'resolved') {
                $requestTimeout = [int][Math]::Ceiling([Math]::Min(5, $TimeoutSeconds - $timer.Elapsed.TotalSeconds))
                if ($requestTimeout -lt 1) { break }
                $alarms = Read-SmokeApi "$homeApi/alarms?active=false&limit=500" $requestTimeout
                $candidates = @($alarms | Where-Object { $_.id -eq $AlarmId })
                if ($open.Count -ne 0) { $candidates = @() }
            }
            else {
                $candidates = $open
            }

            if ($candidates.Count -eq 1) {
                $alarm = $candidates[0]
                $sourceMatches = if ($SourceId -gt 0) {
                    $alarm.source_event_id -eq $SourceId
                }
                else {
                    $alarm.source_event_id -in $matchingEvents.id
                }
                # QoS 1 may deliver the same publication again. Require the
                # alarm to reference records matching this exact publication.
                if ($alarm.home_id -ceq $homeId -and $alarm.device_id -ceq $deviceId -and
                    $alarm.alarm_type -ceq 'sos' -and $alarm.severity -ceq 'critical' -and
                    $alarm.status -ceq $ExpectedStatus -and [long]$alarm.id -gt 0 -and
                    ($AlarmId -eq 0 -or $alarm.id -eq $AlarmId) -and
                    $sourceMatches -and
                    $alarm.last_event_id -in $matchingEvents.id -and
                    ($ExpectedStatus -ne 'resolved' -or
                        ($alarm.resolved_at -and $alarm.resolution_source -ceq 'sensor'))) {
                    if ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
                        return $alarm
                    }
                }
            }
        }
        $sleepMs = [int][Math]::Max(0, [Math]::Min(500, ($TimeoutSeconds - $timer.Elapsed.TotalSeconds) * 1000))
        Start-Sleep -Milliseconds $sleepMs
    }
    if ($foundEvent) {
        throw "Timeout $EventType. API zapisalo zdarzenie, ale nie potwierdzilo odpowiedniego stanu alarmu."
    }
    throw "Timeout $EventType. API nie zwrocilo nowego zdarzenia z czasem $timestamp."
}

$mutex = $null
$locked = $false
try {
    if (-not $ConfirmIsolatedEnvironment) {
        throw 'Uzyj -ConfirmIsolatedEnvironment po sprawdzeniu osobnej bazy testowej i backendu bez Firebase.'
    }
    if ([string]::IsNullOrWhiteSpace($global:VEDASENTIO_ACCESS_TOKEN)) {
        throw 'Uruchom .\scripts\login_api_dev.ps1 w tym samym terminalu.'
    }
    $mutex = [Threading.Mutex]::new($false, 'VedaSentioSosSmoke1270018080')
    try { $locked = $mutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Inny lokalny smoke SOS jest juz uruchomiony.' }

    $headers = @{ Authorization = "Bearer $global:VEDASENTIO_ACCESS_TOKEN" }
    $health = Read-SmokeApi "$api/health"
    if ($health.service -cne 'vedasentio-backend' -or $health.status -cne 'ok') {
        throw 'Pod portem 8080 nie ma zdrowego API VedaSentio.'
    }
    $me = Read-SmokeApi "$api/me"
    if ($homeId -cnotin @($me.homes | ForEach-Object { $_.home_id })) {
        throw "Konto testowe nie ma dostepu do $homeId."
    }
    $device = @(Read-SmokeApi "$homeApi/devices" | Where-Object {
        $_.id -ceq $deviceId -and $_.device_type -ceq 'sos_button' -and $_.is_active -eq $true
    })
    if ($device.Count -ne 1) { throw "Brak aktywnego urzadzenia SOS $deviceId." }
    $null = Read-SmokeApi "$homeApi/alarms?active=false&limit=1"
    if ($env:GOOGLE_APPLICATION_CREDENTIALS) {
        throw 'Usun GOOGLE_APPLICATION_CREDENTIALS z konfiguracji testu i uruchom backend bez Firebase.'
    }

    $timestampMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $opened = Invoke-SosStep 'sos_pressed' $true $timestampMs 0 0 0 'active'
    Write-Host "[SMOKE] Utworzono alarm SOS $($opened.id) ze zdarzenia $($opened.source_event_id)."

    $timestampMs = [Math]::Max($timestampMs + 1, [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
    $repeated = Invoke-SosStep 'sos_pressed' $true $timestampMs $opened.id $opened.source_event_id $opened.last_event_id 'active'
    Write-Host "[SMOKE] Ponowne SOS pozostawilo jeden aktywny alarm $($repeated.id)."

    $timestampMs = [Math]::Max($timestampMs + 1, [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
    $resolved = Invoke-SosStep 'sos_resolved' $false $timestampMs $opened.id $opened.source_event_id $repeated.last_event_id 'resolved'
    Write-Host "[SMOKE] PASS - alarm SOS $($resolved.id) rozwiazany i widoczny w historii."
}
catch {
    throw "[SMOKE] FAIL - $($_.Exception.Message)"
}
finally {
    if ($locked) { $mutex.ReleaseMutex() }
    if ($null -ne $mutex) { $mutex.Dispose() }
}
