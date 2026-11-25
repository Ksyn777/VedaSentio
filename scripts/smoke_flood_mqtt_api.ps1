#Requires -Version 7.0
param(
    [string]$QaId=$global:VEDASENTIO_QA_ID,
    [string]$ApiBaseUrl=$env:VEDASENTIO_API_BASE_URL,
    [string]$MqttContainer=$env:VEDASENTIO_TEST_MQTT_CONTAINER,
    [ValidateRange(1,60)][int]$TimeoutSeconds=15
)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/flood_smoke_common.ps1"
try {
    Invoke-FloodSmoke -QaId $QaId -ApiBaseUrl $ApiBaseUrl -MqttContainer $MqttContainer -Token $global:VEDASENTIO_ACCESS_TOKEN -TimeoutSeconds $TimeoutSeconds
} catch {
    throw "[FLOOD] FAIL - $($_.Exception.Message)"
}
