# Unit tests of the real smoke orchestration with simulated transport only.
# These tests are NOT evidence of MQTT/PostgreSQL/API E2E.
$ErrorActionPreference='Stop'
. "$PSScriptRoot/flood_smoke_common.ps1"
# Exercise the actual API adapter against Invoke-RestMethod's non-enumerated array shape.
function Invoke-RestMethod {
    param($Uri,$Headers,$TimeoutSec,$MaximumRedirection)
    return ,@([pscustomobject]@{id='door_001'},[pscustomobject]@{id='flood_001'})
}
$adapterRows=@(Get-FloodApi 'http://127.0.0.1:18080' 'devices' 'synthetic-unit-token')
if ($adapterRows.Count -ne 2 -or $adapterRows[1].id -ne 'flood_001') { throw 'API adapter did not enumerate response rows.' }
Remove-Item Function:Invoke-RestMethod
Write-Host '[UNIT] PASS actual API adapter enumerates response array.'
function Assert-FloodQaInstance {
    param($QaId,$ApiBaseUrl,$MqttContainer)
    if ($script:case -eq 'foreign-qa' -or $QaId -ne '123456abcdef') { throw 'QA identity mismatch.' }
}
function Get-FloodApi {
    param($BaseUrl,$Path,$Token)
    if ($script:case -in @('401','403','backend-unavailable')) { throw "API request failed ($script:case)." }
    if ($Path -eq 'devices') {
        if ($script:case -eq 'missing-device') { return @() }
        return [pscustomobject]@{id='flood_001';home_id='home_001';device_type='flood_sensor';is_active=($script:case -ne 'inactive-device')}
    }
    if ($Path -like 'events*') { return $script:events }
    if ($script:phase -eq 0) {
        if ($script:case -in @('existing-active','existing-acknowledged')) {
            return [pscustomobject]@{id=40;home_id='home_001';device_id='flood_001';alarm_type='flood';status=($script:case -replace 'existing-','')}
        }
        return @()
    }
    $alarm=[pscustomobject]@{id=50;home_id='home_001';device_id='flood_001';alarm_type='flood';severity='warning';status='active';source_event_id=101;last_event_id=($script:phase*100+1);resolution_source=$null;resolved_at=$null}
    if ($script:phase -eq 3) { $alarm.status='resolved';$alarm.resolution_source='sensor';$alarm.resolved_at='2026-11-25T10:00:00Z' }
    switch ($script:case) {
        'wrong-type' {$alarm.alarm_type='sos'}
        'wrong-device' {$alarm.device_id='other'}
        'wrong-id' {if ($script:phase -gt 1) {$alarm.id=51}}
        'wrong-source' {$alarm.source_event_id=99}
        'wrong-last' {$alarm.last_event_id=99}
        'wrong-severity' {$alarm.severity='critical'}
        'wrong-resolution' {if ($script:phase -eq 3) {$alarm.resolution_source='user'}}
    }
    if ($Path -like '*active=true*' -and $script:phase -eq 3) { return @() }
    if ($script:case -eq 'duplicate-alarm' -and $script:phase -eq 2) { return @($alarm,$alarm) }
    return $alarm
}
function Send-FloodEvent {
    param($EventType,$Value,$Timestamp,$Container)
    $script:phase++;$script:publications++
    if ($script:case -eq 'timeout') { return }
    $event=[pscustomobject]@{id=($script:phase*100+1);home_id='home_001';device_id='flood_001';event_type=$EventType;value=$Value;device_timestamp=$Timestamp}
    if ($script:case -eq 'stale-event') {$event.device_timestamp='2000-01-01T00:00:00Z'}
    $script:events+= $event
    if ($script:case -eq 'qos-duplicate') { $duplicate=$event.PSObject.Copy(); $duplicate.id++; $script:events+= $duplicate }
}
$checks=0
$noPublication=@('missing-jwt','401','403','missing-device','inactive-device','existing-active','existing-acknowledged','backend-unavailable','foreign-qa')
$failures=$noPublication+@('timeout','wrong-type','wrong-device','wrong-id','wrong-source','wrong-last','wrong-severity','wrong-resolution','duplicate-alarm','stale-event')
foreach ($scenario in @('valid','qos-duplicate')+$failures) {
    $script:case=$scenario;$script:phase=0;$script:publications=0;$script:events=@();$failed=$false
    $token=if ($scenario -eq 'missing-jwt') { '' } else { 'synthetic-unit-token' }
    try { Invoke-FloodSmoke -QaId '123456abcdef' -ApiBaseUrl http://127.0.0.1:18080 -MqttContainer vsqa-123456abcdef-mqtt -Token $token -TimeoutSeconds 1 6>$null }
    catch { $failed=$true }
    if ($scenario -in $failures) {
        if (-not $failed) {throw "False success in $scenario"}
        if ($scenario -in $noPublication -and $script:publications -ne 0) {throw "Unexpected publication in $scenario"}
    } elseif ($failed -or $script:publications -ne 3) { throw "Valid flow rejected: $scenario" }
    $checks++;Write-Host "[UNIT] PASS $scenario (publications=$script:publications)"
}
Get-ChildItem "$PSScriptRoot/*.ps1" | ForEach-Object {
    $tokens=$null;$errors=$null
    [Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)|Out-Null
    if ($errors) {throw "PowerShell syntax error in $($_.Name)"}
}
Write-Host "[UNIT] $checks flood scenarios passed; PowerShell syntax passed. E2E requires real integration."
exit 0
