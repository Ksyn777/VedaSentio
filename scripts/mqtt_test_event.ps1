param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EventType,

    [string]$ValueJson = "true",

    [string]$HomeId = "home_001",

    [string]$DeviceId = "sos_001",

    [ValidateRange(0, 2)]
    [int]$Qos = 1
)

$ErrorActionPreference = "Stop"

function Get-MqttPassword {
    if (
        -not [string]::IsNullOrWhiteSpace(
            $env:VEDASENTIO_MQTT_PASSWORD
        )
    ) {
        return $env:VEDASENTIO_MQTT_PASSWORD
    }

    $secure = Read-Host `
        "MQTT password" `
        -AsSecureString

    $pointer =
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            $secure
        )

    try {
        $plain =
            [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
                $pointer
            )

        $env:VEDASENTIO_MQTT_PASSWORD = $plain
        return $plain
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
            $pointer
        )
    }
}

$mqttUser = $env:VEDASENTIO_MQTT_USER

if ([string]::IsNullOrWhiteSpace($mqttUser)) {
    $mqttUser = "vedasentio_backend"
}

$runningContainer = docker ps `
    --filter "name=^/vedasentio-mqtt$" `
    --format "{{.Names}}"

if ($LASTEXITCODE -ne 0) {
    throw "Nie udalo sie sprawdzic Docker."
}

if ($runningContainer -ne "vedasentio-mqtt") {
    throw "Kontener vedasentio-mqtt nie jest uruchomiony."
}

try {
    $value = $ValueJson | ConvertFrom-Json
}
catch {
    throw "ValueJson musi zawierac poprawna wartosc JSON, np. true, false, 12.5 lub '{`"active`":true}'."
}

$timestamp =
    (Get-Date).ToUniversalTime().ToString(
        "yyyy-MM-ddTHH:mm:ss.fffZ"
    )

$topic =
    "vedasentio/$HomeId/$DeviceId/event"

$payload = @{
    event_type = $EventType
    value = $value
    timestamp = $timestamp
} |
    ConvertTo-Json -Compress

$mqttPassword = Get-MqttPassword

Write-Host ""
Write-Host "[MQTT-TEST] Publishing structured event..."
Write-Host "[MQTT-TEST] Topic:      $topic"
Write-Host "[MQTT-TEST] Event type: $EventType"
Write-Host "[MQTT-TEST] Timestamp:  $timestamp"
Write-Host "[MQTT-TEST] Password is not printed."

$payload |
    docker exec -i vedasentio-mqtt `
        mosquitto_pub `
        -h 127.0.0.1 `
        -p 1883 `
        -u $mqttUser `
        -P $mqttPassword `
        -t $topic `
        -q $Qos `
        -s

if ($LASTEXITCODE -ne 0) {
    throw "Publikacja MQTT nie powiodla sie."
}

Write-Host "[MQTT-TEST] Event published successfully."
Write-Host ""
