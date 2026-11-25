#Requires -Version 7.0
param(
    [switch]$ConfirmIsolatedEnvironment,
    [ValidateRange(1,65535)][int]$DbPort = 15433,
    [ValidateRange(1,65535)][int]$MqttPort = 28883,
    [ValidateRange(1,65535)][int]$ApiPort = 18080,
    [string]$BackendPath = "$PSScriptRoot/../backend/build/Debug/vedasentio_backend.exe"
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/qa_local_common.ps1"
if (-not $ConfirmIsolatedEnvironment) { throw 'Pass -ConfirmIsolatedEnvironment to create disposable QA resources.' }
if (-not $IsWindows) { throw 'This launcher requires Windows PowerShell 7.' }
Assert-QaLocalDocker
if (@($DbPort,$MqttPort,$ApiPort | Select-Object -Unique).Count -ne 3) { throw 'QA ports must be distinct.' }
foreach ($port in @($DbPort,$MqttPort,$ApiPort)) { Assert-QaPortFree $port }
if (-not (Test-Path -LiteralPath $BackendPath -PathType Leaf)) {
    throw 'Backend executable missing. Run cmake -S backend -B backend/build with the vcpkg toolchain, then cmake --build backend/build --config Debug --parallel 2. No resources created.'
}
$BackendPath = (Resolve-Path -LiteralPath $BackendPath).Path
$id = [Guid]::NewGuid().ToString('N').Substring(0,12)
$statePath = Get-QaStatePath $id
New-Item -ItemType Directory -Path (Split-Path $statePath) | Out-Null
$state = [ordered]@{ Id=$id; Network=$null; Db=$null; Mqtt=$null; Backend=$null; ApiPort=$ApiPort; DbPort=$DbPort; MqttPort=$MqttPort }
function Save-QaState { $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath }
function Invoke-QaDocker {
    param([string[]]$DockerArgs)
    $result = & docker @DockerArgs 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'QA Docker command failed (credentials suppressed). Use the QA ID for cleanup.' }
    return $result
}
function New-QaSecret { return [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)) }
$dbName = "vsqa_$id"
$dbUser = "qa_$id"
$dbPassword = New-QaSecret
$mqttPassword = New-QaSecret
$qaEnv = @{
    VEDASENTIO_DB_HOST='127.0.0.1'; VEDASENTIO_DB_PORT="$DbPort"; VEDASENTIO_DB_NAME=$dbName
    VEDASENTIO_DB_USER=$dbUser; VEDASENTIO_DB_PASSWORD=$dbPassword
    VEDASENTIO_MQTT_USER='qa_backend'; VEDASENTIO_MQTT_PASSWORD=$mqttPassword
    VEDASENTIO_MQTT_PORT="$MqttPort"; VEDASENTIO_API_PORT="$ApiPort"
    VEDASENTIO_DATA_ENCRYPTION_KEY_B64=(New-QaSecret); VEDASENTIO_LOOKUP_HMAC_KEY_B64=(New-QaSecret)
    VEDASENTIO_JWT_SIGNING_KEY_B64=(New-QaSecret)
    VEDASENTIO_API_BASE_URL="http://127.0.0.1:$ApiPort"; VEDASENTIO_TEST_MQTT_CONTAINER="vsqa-$id-mqtt"
}
Save-QaState
Write-Host "[QA] Environment ID: $id (disposable data in tmpfs)"
try {
    $state.Network=Invoke-QaDocker @('network','create','--label',"org.vedasentio.qa=$id", "vsqa-$id")
    Save-QaState
    # Pass the password through the Docker CLI environment, never a command argument or file.
    $previousPgPassword = $env:POSTGRES_PASSWORD
    try {
        $env:POSTGRES_PASSWORD = $dbPassword
        $state.Db = Invoke-QaDocker @('run','-d','--network',"vsqa-$id",'--name',"vsqa-$id-db",'--label',"org.vedasentio.qa=$id",'--label','org.vedasentio.qa.role=db',
            '--tmpfs','/var/lib/postgresql/data','-p',"127.0.0.1:${DbPort}:5432",'-e',"POSTGRES_DB=$dbName",'-e',"POSTGRES_USER=$dbUser",'-e','POSTGRES_PASSWORD','postgres:17')
    } finally { $env:POSTGRES_PASSWORD = $previousPgPassword }
    Save-QaState
    $state.Mqtt = Invoke-QaDocker @('run','-d','--network',"vsqa-$id",'--name',"vsqa-$id-mqtt",'--label',"org.vedasentio.qa=$id",'--label','org.vedasentio.qa.role=mqtt',
        '--user','1883:1883','--tmpfs','/mosquitto/data:uid=1883,gid=1883','--tmpfs','/mosquitto/log:uid=1883,gid=1883','--tmpfs','/mosquitto/config:uid=1883,gid=1883,mode=0700','-p',"127.0.0.1:${MqttPort}:1883",'--entrypoint','sh','eclipse-mosquitto:2',
        '-c','while [ ! -f /mosquitto/config/ready ]; do sleep 1; done; exec mosquitto -c /mosquitto/config/qa.conf')
    Save-QaState
    "listener 1883`nallow_anonymous false`npassword_file /mosquitto/config/passwords`npersistence false" |
        docker exec -i $state.Mqtt sh -c 'cat > /mosquitto/config/qa.conf'
    if ($LASTEXITCODE -ne 0) { throw 'MQTT configuration failed.' }
    # Only salted hashes are written; password lives briefly in this exec argument, as in mosquitto_pub.
    Invoke-QaDocker @('exec',$state.Mqtt,'mosquitto_passwd','-b','-c','/mosquitto/config/passwords','qa_backend',$mqttPassword) | Out-Null
    Invoke-QaDocker @('exec',$state.Mqtt,'touch','/mosquitto/config/ready') | Out-Null
    $ready = $false
    for ($attempt=0; $attempt -lt 60; $attempt++) {
        docker exec $state.Db pg_isready -U $dbUser -d $dbName *> $null
        if ($LASTEXITCODE -eq 0) { $ready=$true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw 'New PostgreSQL readiness timed out.' }
    $mqttReady=$false
    for ($attempt=0; $attempt -lt 30; $attempt++) {
        docker exec $state.Mqtt mosquitto_pub -h 127.0.0.1 -u qa_backend -P $mqttPassword -t qa/readiness -n *> $null
        if ($LASTEXITCODE -eq 0) { $mqttReady=$true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $mqttReady) { throw 'New authenticated MQTT readiness timed out.' }
    $repo = Split-Path $PSScriptRoot
    $sqlFiles = @(Get-ChildItem "$repo/database/0*_*.sql" | Sort-Object Name)
    $sqlFiles += Get-Item "$repo/database/dev_seed.sql"
    foreach ($file in $sqlFiles) {
        Get-Content -LiteralPath $file.FullName -Raw | docker exec -i $state.Db psql -U $dbUser -d $dbName -v ON_ERROR_STOP=1 *> $null
        if ($LASTEXITCODE -ne 0) { throw "QA migration failed: $($file.Name)" }
    }
    # Explicit environment avoids Start-Job inheritance assumptions. Never copy Firebase into QA.
    $start = [Diagnostics.ProcessStartInfo]::new($BackendPath)
    $start.UseShellExecute=$false
    $start.ArgumentList.Add("--qa-instance=$id")
    $start.Environment.Remove('GOOGLE_APPLICATION_CREDENTIALS') | Out-Null
    foreach ($key in $qaEnv.Keys) { $start.Environment[$key]=$qaEnv[$key] }
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $backend = [Diagnostics.Process]::Start($start)
    # Drain output asynchronously without writing raw service diagnostics or secrets to disk.
    $outTask=$backend.StandardOutput.ReadToEndAsync(); $errTask=$backend.StandardError.ReadToEndAsync()
    $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId=$($backend.Id)"
    $state.Backend=@{Pid=$backend.Id; Path=$BackendPath; CreatedTicks=$processInfo.CreationDate.ToUniversalTime().Ticks}
    Save-QaState
    $healthy=$false
    for ($attempt=0; $attempt -lt 60; $attempt++) {
        if ($backend.HasExited) { throw 'QA backend exited. Check binary dependencies and configuration; raw logs suppressed.' }
        try {
            $health=Invoke-RestMethod "$($qaEnv.VEDASENTIO_API_BASE_URL)/api/health" -TimeoutSec 2 -MaximumRedirection 0
            $healthy=$true; break
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $healthy) { throw 'QA health check timed out.' }
    # Export only to the current shell for login, user creation and publishing. No credentials in state.json.
    foreach ($key in $qaEnv.Keys) { [Environment]::SetEnvironmentVariable($key,$qaEnv[$key],'Process') }
    $global:VEDASENTIO_QA_ID=$id
    Write-Host "[QA] READY $($qaEnv.VEDASENTIO_API_BASE_URL). Credentials only in this shell; Firebase disabled."
    Write-Host "[QA] Stop: ./scripts/stop_isolated_qa.ps1 -Id $id -ConfirmStop"
} catch {
    Write-Host "[QA] Incomplete startup. Resources are recorded at $statePath. Stop only this ID: $id"
    throw
}
