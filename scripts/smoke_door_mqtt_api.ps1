param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("opened", "closed")]
    [string]$State,

    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 15,
    [string]$ApiBaseUrl = $env:VEDASENTIO_API_BASE_URL,
    [string]$MqttContainer = $env:VEDASENTIO_TEST_MQTT_CONTAINER
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/qa_local_common.ps1"
$ApiBaseUrl = Get-QaApiBaseUrl $ApiBaseUrl
$MqttContainer = Get-QaMqttContainer $MqttContainer
Assert-QaLocalDocker

# The login helper saves JWT in the current PowerShell session.
if ([string]::IsNullOrWhiteSpace($global:VEDASENTIO_ACCESS_TOKEN)) {
    throw "Najpierw uruchom .\scripts\login_api_dev.ps1 w tym samym terminalu."
}

$homeId = "home_001"
$deviceId = "door_001"
$eventsUrl = "$ApiBaseUrl/api/homes/$homeId/events?limit=100"
$headers = @{
    Authorization = "Bearer $global:VEDASENTIO_ACCESS_TOKEN"
}

# Check API authorization before publishing any test event.
$previousEvents = Invoke-RestMethod -Method Get -Uri $eventsUrl -Headers $headers -TimeoutSec 5 -MaximumRedirection 0

[long]$lastId = 0
foreach ($event in $previousEvents) {
    if ($null -ne $event -and [long]$event.id -gt $lastId) {
        $lastId = [long]$event.id
    }
}

$eventType = "door_$State"
$expectedValue = $State -eq "opened"

# A unique event timestamp distinguishes our publication from another
# identical event sent by a different test process.
$timestampUtc = (Get-Date).ToUniversalTime().ToString(
    "yyyy-MM-ddTHH:mm:ss.fffZ"
)
$expectedTimestampMs = [DateTimeOffset]::Parse(
    $timestampUtc,
    [Globalization.CultureInfo]::InvariantCulture
).ToUnixTimeMilliseconds()

Write-Host "[SMOKE] Ostatni zapisany event ID: $lastId"
Write-Host "[SMOKE] Wysylanie zdarzenia: $eventType"

$publisher = Join-Path $PSScriptRoot "mqtt_test_door_contact.ps1"
& $publisher -State $State -TimestampUtc $timestampUtc -MqttContainer $MqttContainer

# A successful publish alone does not prove that the backend saved it.
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)

while ([DateTime]::UtcNow -lt $deadline) {
    $events = Invoke-RestMethod -Method Get -Uri $eventsUrl -Headers $headers -TimeoutSec 5 -MaximumRedirection 0

    foreach ($event in $events) {
        if ($null -eq $event) {
            continue
        }

        $correctEvent = [long]$event.id -gt $lastId -and
            $event.home_id -eq $homeId -and
            $event.device_id -eq $deviceId -and
            $event.event_type -eq $eventType -and
            $event.value -is [bool] -and
            $event.value -eq $expectedValue

        if (-not $correctEvent) {
            continue
        }

        try {
            $receivedTimestampMs = [DateTimeOffset]::Parse(
                [string]$event.device_timestamp,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AssumeUniversal
            ).ToUnixTimeMilliseconds()
        }
        catch {
            continue
        }

        if ($receivedTimestampMs -eq $expectedTimestampMs) {
            Write-Host "[SMOKE] PASS - backend zapisal nasz event $eventType."
            Write-Host "[SMOKE] Event ID: $($event.id)"
            return
        }
    }

    Start-Sleep -Milliseconds 500
}

throw "[SMOKE] FAIL - nie znaleziono nowego zdarzenia $eventType w API. Sprawdz backend, MQTT i PostgreSQL."
