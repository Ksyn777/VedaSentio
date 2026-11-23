param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("opened", "closed")]
    [string]$State,

    [string]$TimestampUtc = ""
)

$ErrorActionPreference = "Stop"

$mqttTestScript = Join-Path $PSScriptRoot "mqtt_test_event.ps1"

if ($State -eq "opened") {
    $eventType = "door_opened"
    $valueJson = "true"
}
else {
    $eventType = "door_closed"
    $valueJson = "false"
}

& $mqttTestScript `
    -EventType $eventType `
    -ValueJson $valueJson `
    -HomeId "home_001" `
    -DeviceId "door_001" `
    -TimestampUtc $TimestampUtc
