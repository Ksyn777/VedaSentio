#Requires -Version 7.0
param([Parameter(Mandatory)][string]$Id, [switch]$ConfirmStop)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/qa_local_common.ps1"
if (-not $ConfirmStop) { throw 'Pass -ConfirmStop to remove only this disposable QA environment.' }
Assert-QaLocalDocker
$statePath=Get-QaStatePath $Id
$state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if ($state.Id -cne $Id) { throw 'State identity mismatch.' }
# Verify ALL identities before stopping ANY resource. Missing resources are left alone.
$containers=@()
foreach ($role in @('db','mqtt')) {
    $containerId=if ($role -eq 'db') { $state.Db } else { $state.Mqtt }
    if (-not $containerId) { continue }
    if ($containerId -cnotmatch '^[a-f0-9]{64}$') { throw 'Invalid container identity in state.' }
    $raw=docker container inspect $containerId 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "[QA] $role already absent."; continue }
    $container=@($raw | ConvertFrom-Json)[0]
    Assert-QaContainerIdentity $container $Id $role $containerId
    $containers += $containerId
}
if ($state.Network) {
    if ($state.Network -cnotmatch '^[a-f0-9]{64}$') { throw 'Invalid QA network identity.' }
    $rawNetwork=docker network inspect $state.Network 2>$null
    if ($LASTEXITCODE -eq 0) {
        $network=@($rawNetwork | ConvertFrom-Json)[0]
        if ($network.Id -cne $state.Network -or $network.Name -cne "vsqa-$Id" -or $network.Labels.'org.vedasentio.qa' -cne $Id) {
            throw 'Network ownership mismatch. Nothing will be stopped.'
        }
        foreach ($member in $network.Containers.PSObject.Properties.Name) {
            if ($member -notin @($state.Db,$state.Mqtt)) { throw 'Foreign member in QA network. Nothing will be stopped.' }
        }
    } else { Write-Host '[QA] Network already absent.'; $state.Network=$null }
}
$backendProcess=$null
if ($state.Backend) {
    $backendProcess=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.Backend.Pid)"
    if ($backendProcess) { Assert-QaBackendIdentity $backendProcess $state.Backend $Id }
    else { Write-Host '[QA] Backend already absent.' }
}
if ($backendProcess) {
    # Recheck against PID reuse immediately before terminating.
    $live=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.Backend.Pid)"
    if ($live) {
        Assert-QaBackendIdentity $live $state.Backend $Id
        $result=Invoke-CimMethod -InputObject $live -MethodName Terminate
        if ($result.ReturnValue -ne 0) { throw 'Could not stop QA backend.' }
        Write-Host '[QA] Stopped owned backend.'
    }
}
foreach ($containerId in $containers) {
    docker rm -f $containerId | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not remove owned QA container.' }
    Write-Host "[QA] Removed owned container $($containerId.Substring(0,12)); tmpfs data discarded."
}
if ($state.Network) {
    docker network rm $state.Network | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not remove owned QA network.' }
    Write-Host '[QA] Removed owned QA network.'
}
Write-Host '[QA] Other processes, containers, networks and volumes left unchanged. State retained without secrets.'
