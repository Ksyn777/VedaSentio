#Requires -Version 7.0
param([switch]$ConfirmIsolatedEnvironment, [string]$BackendPath="$PSScriptRoot/../backend/build/Debug/vedasentio_backend.exe")
$ErrorActionPreference='Stop'
if (-not $ConfirmIsolatedEnvironment) { throw 'Explicit confirmation required for disposable integration services.' }
. "$PSScriptRoot/qa_local_common.ps1"
Assert-QaLocalDocker
function Get-ExistingInventory {
    $ids=@(docker ps -aq)
    if ($LASTEXITCODE -ne 0) { throw 'Docker inventory failed.' }
    if (-not $ids.Count) { return '' }
    # Hash configuration and start times in memory; never persist potentially secret Docker inspect output.
    $json=docker inspect @ids
    if ($LASTEXITCODE -ne 0) { throw 'Docker inspection failed.' }
    $summary=@($json | ConvertFrom-Json | Sort-Object Id | ForEach-Object {
        [ordered]@{Id=$_.Id;Config=$_.Config;HostConfig=$_.HostConfig;Mounts=@($_.Mounts | Sort-Object Destination);StartedAt=$_.State.StartedAt}
    }) | ConvertTo-Json -Depth 30 -Compress
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($summary)))
}
$inventory=Get-ExistingInventory
$global:VEDASENTIO_QA_ID=$null
$testId=$null
try {
    & "$PSScriptRoot/start_isolated_qa.ps1" -ConfirmIsolatedEnvironment -BackendPath $BackendPath
    $testId=$global:VEDASENTIO_QA_ID
    if (-not $testId) { throw 'QA did not start.' }
    $state=Get-Content (Get-QaStatePath $testId) -Raw | ConvertFrom-Json
    . "$PSScriptRoot/flood_smoke_common.ps1"
    Assert-FloodQaInstance $testId $env:VEDASENTIO_API_BASE_URL $env:VEDASENTIO_TEST_MQTT_CONTAINER
    Get-Content "$PSScriptRoot/../database/qa/flood_seed.sql" -Raw | docker exec -i $state.Db psql -U $env:VEDASENTIO_DB_USER -d $env:VEDASENTIO_DB_NAME -v ON_ERROR_STOP=1 *> $null
    if ($LASTEXITCODE) { throw 'Isolated flood QA seed failed.' }
    $stateJson=$state | ConvertTo-Json -Depth 6
    foreach ($name in @('VEDASENTIO_DB_PASSWORD','VEDASENTIO_MQTT_PASSWORD','VEDASENTIO_JWT_SIGNING_KEY_B64','VEDASENTIO_DATA_ENCRYPTION_KEY_B64','VEDASENTIO_LOOKUP_HMAC_KEY_B64')) {
        if ($stateJson.Contains([Environment]::GetEnvironmentVariable($name))) { throw 'Secret leaked to state.' }
    }
    $busyRejected=$false
    try { & "$PSScriptRoot/start_isolated_qa.ps1" -ConfirmIsolatedEnvironment -BackendPath $BackendPath }
    catch { $busyRejected=$_.Exception.Message -match 'busy' }
    if (-not $busyRejected) { throw 'Occupied alternative port was not rejected.' }
    # A deliberately wrong environment ID must never stop even our other QA container.
    $foreignId=[Guid]::NewGuid().ToString('N').Substring(0,12)
    $foreignStatePath=Get-QaStatePath $foreignId
    New-Item -ItemType Directory -Path (Split-Path $foreignStatePath) | Out-Null
    @{Id=$foreignId;Db=$state.Db;Mqtt=$null;Backend=$null} | ConvertTo-Json | Set-Content $foreignStatePath
    $foreignRejected=$false
    try { & "$PSScriptRoot/stop_isolated_qa.ps1" -Id $foreignId -ConfirmStop }
    catch { $foreignRejected=$_.Exception.Message -match 'ownership mismatch' }
    if (-not $foreignRejected) { throw 'Foreign container was not rejected.' }
    $env:VEDASENTIO_NEW_USER_EMAIL='demo@example.invalid'
    $env:VEDASENTIO_NEW_USER_PASSWORD=[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    $env:VEDASENTIO_NEW_USER_FIRST_NAME='Demo'; $env:VEDASENTIO_NEW_USER_LAST_NAME='QA'
    $env:VEDASENTIO_NEW_USER_PHONE='+48000000000'
    $env:VEDASENTIO_NEW_USER_HOME_ID='home_001'; $env:VEDASENTIO_NEW_USER_ROLE='owner'
    $binaryDir=Split-Path (Resolve-Path $BackendPath)
    & "$binaryDir/vedasentio_create_dev_user.exe"
    if ($LASTEXITCODE -ne 0) { throw 'QA user creation failed.' }
    $login=Invoke-RestMethod -Method Post -Uri "$env:VEDASENTIO_API_BASE_URL/api/auth/login" -ContentType application/json -Body (@{email=$env:VEDASENTIO_NEW_USER_EMAIL;password=$env:VEDASENTIO_NEW_USER_PASSWORD}|ConvertTo-Json) -MaximumRedirection 0
    $global:VEDASENTIO_ACCESS_TOKEN=$login.access_token
    & "$PSScriptRoot/smoke_door_mqtt_api.ps1" -State opened
    & "$PSScriptRoot/smoke_door_mqtt_api.ps1" -State closed
    & "$PSScriptRoot/smoke_flood_mqtt_api.ps1" -QaId $testId
    & "$binaryDir/vedasentio_alarm_flow_test.exe"
    if ($LASTEXITCODE -ne 0) { throw 'Alarm regression failed.' }
    Write-Host '[QA] PASS - istniejaca regresja alarmow.'

} finally {
    if (-not $testId) { $testId=$global:VEDASENTIO_QA_ID }
    if ($testId) { & "$PSScriptRoot/stop_isolated_qa.ps1" -Id $testId -ConfirmStop }
    if ((Get-ExistingInventory) -cne $inventory) { throw 'Existing Docker configuration or start times changed.' }
    Write-Host '[QA] Existing container configuration, mounts and start times unchanged.'
}
Write-Host '[QA] PASS: authenticated API observed both fresh door events and the complete flood cycle; alarm regression, occupied port, state secrecy and foreign ownership checks passed.'
