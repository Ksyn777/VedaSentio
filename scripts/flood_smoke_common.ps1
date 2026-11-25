# Flood smoke implementation; transport boundaries are replaced only by unit tests.
. "$PSScriptRoot/qa_local_common.ps1"

function Assert-FloodQaInstance {
    param([string]$QaId, [string]$ApiBaseUrl, [string]$MqttContainer)
    Assert-QaLocalDocker
    $state=Get-Content -LiteralPath (Get-QaStatePath $QaId) -Raw | ConvertFrom-Json
    if ($state.Id -cne $QaId -or $ApiBaseUrl -cne "http://127.0.0.1:$($state.ApiPort)" -or
        $MqttContainer -cne "vsqa-$QaId-mqtt" -or -not $state.Backend) { throw 'QA identity/address mismatch.' }
    foreach ($entry in @(@{Role='db';Id=$state.Db;Port='5432/tcp';HostPort=$state.DbPort},@{Role='mqtt';Id=$state.Mqtt;Port='1883/tcp';HostPort=$state.MqttPort})) {
        if ($entry.Id -cnotmatch '^[a-f0-9]{64}$') { throw 'Invalid QA container identity.' }
        $raw=docker container inspect $entry.Id 2>$null
        if ($LASTEXITCODE) { throw 'QA container unavailable.' }
        $container=@($raw | ConvertFrom-Json)[0]
        Assert-QaContainerIdentity $container $QaId $entry.Role $entry.Id
        $bindings=@($container.NetworkSettings.Ports.($entry.Port))
        $network=$container.NetworkSettings.Networks."vsqa-$QaId"
        if (-not $container.State.Running -or $bindings.Count -ne 1 -or $bindings[0].HostIp -ne '127.0.0.1' -or
            $bindings[0].HostPort -ne [string]$entry.HostPort -or $network.NetworkID -cne $state.Network) {
            throw 'QA container ports/network mismatch.'
        }
    }
    if ($state.Network -cnotmatch '^[a-f0-9]{64}$') { throw 'Invalid QA network identity.' }
    $raw=docker network inspect $state.Network 2>$null
    if ($LASTEXITCODE) { throw 'QA network unavailable.' }
    $network=@($raw | ConvertFrom-Json)[0]
    if ($network.Name -cne "vsqa-$QaId" -or $network.Labels.'org.vedasentio.qa' -cne $QaId) { throw 'QA network ownership mismatch.' }
    $process=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.Backend.Pid)"
    if (-not $process) { throw 'QA backend unavailable.' }
    Assert-QaBackendIdentity $process $state.Backend $QaId
    $listeners=@(Get-NetTCPConnection -LocalPort $state.ApiPort -State Listen -ErrorAction SilentlyContinue)
    if ($listeners.Count -ne 1 -or $listeners[0].LocalAddress -ne '127.0.0.1' -or
        $listeners[0].OwningProcess -ne $state.Backend.Pid) { throw 'QA API listener ownership mismatch.' }
}

function Get-FloodApi {
    param([string]$BaseUrl, [string]$Path, [string]$Token)
    try {
        $response=Invoke-RestMethod -Uri "$BaseUrl/api/homes/home_001/$Path" -Headers @{Authorization="Bearer $Token"} -TimeoutSec 3 -MaximumRedirection 0
        foreach ($row in $response) { Write-Output $row }
    } catch {
        $status=if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'unavailable' }
        throw "API request failed ($status)."
    }
}

function Send-FloodEvent {
    param([string]$EventType, [bool]$Value, [string]$Timestamp, [string]$Container)
    & "$PSScriptRoot/mqtt_test_event.ps1" -HomeId home_001 -DeviceId flood_001 -EventType $EventType -ValueJson $Value.ToString().ToLowerInvariant() -TimestampUtc $Timestamp -MqttContainer $Container -Qos 1
}

function Get-FloodRows {
    param([string]$BaseUrl, [string]$Path, [string]$Token)
    $rows=@(Get-FloodApi $BaseUrl $Path $Token)
    if ($rows.Count -ge 500) { throw 'API result may be truncated; use fresh isolated QA.' }
    return $rows
}

function Invoke-FloodSmoke {
    param([string]$QaId, [string]$ApiBaseUrl, [string]$MqttContainer, [string]$Token, [int]$TimeoutSeconds=15)
    if ([string]::IsNullOrWhiteSpace($Token)) { throw 'JWT missing; no MQTT publication.' }
    $ApiBaseUrl=Get-QaApiBaseUrl $ApiBaseUrl
    $MqttContainer=Get-QaMqttContainer $MqttContainer
    Assert-FloodQaInstance $QaId $ApiBaseUrl $MqttContainer
    $device=@(Get-FloodApi $ApiBaseUrl 'devices' $Token | Where-Object { $_.home_id -ceq 'home_001' -and $_.id -ceq 'flood_001' })
    if ($device.Count -ne 1 -or $device[0].is_active -isnot [bool] -or -not $device[0].is_active -or $device[0].device_type -cne 'flood_sensor') {
        throw 'Active QA flood_001 device not found.'
    }
    $open=@(Get-FloodRows $ApiBaseUrl 'alarms?active=true&limit=500' $Token | Where-Object { $_.device_id -ceq 'flood_001' -and $_.alarm_type -ceq 'flood' })
    if ($open.Count) { throw 'Existing open flood alarm; no MQTT publication.' }
    $history=@(Get-FloodRows $ApiBaseUrl 'alarms?active=false&limit=500' $Token)
    $events=@(Get-FloodRows $ApiBaseUrl 'events?limit=500' $Token)
    [long]$lastEvent=0; [long]$lastAlarm=0
    foreach ($row in $events) { $lastEvent=[Math]::Max($lastEvent,[long]$row.id) }
    foreach ($row in $history) { $lastAlarm=[Math]::Max($lastAlarm,[long]$row.id) }
    [long]$alarmId=0; [long]$sourceId=0; [long]$previousMs=0
    foreach ($phase in 1..3) {
        # Recheck ownership before each publication, including after a previous stage.
        Assert-FloodQaInstance $QaId $ApiBaseUrl $MqttContainer
        $eventType=if ($phase -eq 3) { 'flood_cleared' } else { 'flood_detected' }
        $value=$phase -ne 3
        $stampMs=[Math]::Max([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(),$previousMs+1)
        $previousMs=$stampMs
        $stamp=[DateTimeOffset]::FromUnixTimeMilliseconds($stampMs).ToString("yyyy-MM-ddTHH:mm:ss.fff'Z'")
        Send-FloodEvent $eventType $value $stamp $MqttContainer
        $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        $passed=$false
        do {
            $events=@(Get-FloodRows $ApiBaseUrl 'events?limit=500' $Token)
            $matching=@($events | Where-Object {
                $event=$_
                $same=$event.home_id -ceq 'home_001' -and $event.device_id -ceq 'flood_001' -and $event.event_type -ceq $eventType -and
                    $event.value -is [bool] -and $event.value -eq $value -and [long]$event.id -gt $lastEvent
                if ($same) {
                    try { $same=[DateTimeOffset]::Parse([string]$event.device_timestamp,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).ToUnixTimeMilliseconds() -eq $stampMs }
                    catch { $same=$false }
                }
                $same
            })
            $history=@(Get-FloodRows $ApiBaseUrl 'alarms?active=false&limit=500' $Token)
            $open=@(Get-FloodRows $ApiBaseUrl 'alarms?active=true&limit=500' $Token | Where-Object { $_.device_id -ceq 'flood_001' -and $_.alarm_type -ceq 'flood' })
            $new=@($history | Where-Object { $_.home_id -ceq 'home_001' -and $_.device_id -ceq 'flood_001' -and $_.alarm_type -ceq 'flood' -and [long]$_.id -gt $lastAlarm })
            if ($open.Count -gt 1 -or $new.Count -gt 1) { throw 'Duplicate flood alarm.' }
            if ($matching.Count -and $new.Count -eq 1) {
                $alarm=$new[0]; $eventIds=@($matching | ForEach-Object { [long]$_.id })
                $identity=($alarmId -eq 0 -or [long]$alarm.id -eq $alarmId) -and $alarm.severity -ceq 'warning'
                $source=if ($phase -eq 1) { [long]$alarm.source_event_id -in $eventIds } else { [long]$alarm.source_event_id -eq $sourceId }
                $last=[long]$alarm.last_event_id -in $eventIds
                $status=if ($phase -eq 3) {
                    $alarm.status -ceq 'resolved' -and $alarm.resolution_source -ceq 'sensor' -and -not [string]::IsNullOrEmpty($alarm.resolved_at) -and $open.Count -eq 0
                } else { $alarm.status -ceq 'active' -and $open.Count -eq 1 -and [long]$open[0].id -eq [long]$alarm.id }
                if ($identity -and $source -and $last -and $status) {
                    $alarmId=[long]$alarm.id; $sourceId=[long]$alarm.source_event_id
                    foreach ($row in $events) { $lastEvent=[Math]::Max($lastEvent,[long]$row.id) }
                    $passed=$true; break
                }
            }
            Start-Sleep -Milliseconds 200
        } while ([DateTime]::UtcNow -lt $deadline)
        if (-not $passed) { throw "Timeout: flood phase $phase not confirmed by API." }
        $label=switch ($phase) { 1 {'wykrycie zalania'} 2 {'brak drugiego otwartego alarmu'} 3 {'zakonczenie zalania i zachowanie historii'} }
        Write-Host "[FLOOD] PASS - $label; alarm ID=$alarmId source_event_id=$sourceId last_event_id=$($alarm.last_event_id)"
    }
}
