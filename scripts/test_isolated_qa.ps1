param([string]$BackendPath)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/qa_local_common.ps1"
$checks = 0
function Assert-Rejected([scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'Expected rejection.' }
    $script:checks++
}
foreach ($url in @('https://127.0.0.1:18080', 'http://example.com', 'http://127.0.0.1.evil.test', 'http://user:secret@127.0.0.1', 'http://127.0.0.1/path', 'http://127.0.0.1?x=y', ' http://127.0.0.1', 'http://127.0.0.1:0')) {
    Assert-Rejected { Get-QaApiBaseUrl $url }
}
foreach ($url in @('http://127.0.0.1:18080', 'http://localhost:8080', 'http://[::1]:18080')) {
    if ((Get-QaApiBaseUrl $url) -ne $url) { throw 'Valid URL rejected.' }; $checks++
}
foreach ($endpoint in @('ssh://host', 'tcp://127.0.0.1:2375', 'tcp://remote:2376', 'unix:///var/run/docker.sock')) {
    Assert-Rejected { Assert-QaDockerEndpoint $endpoint }
}
Assert-QaDockerEndpoint 'npipe:////./pipe/dockerDesktopLinuxEngine'; $checks++
foreach ($name in @('--privileged', 'x y', '../x', '')) {
    if ($name) { Assert-Rejected { Get-QaMqttContainer $name } }
}
if ((Get-QaMqttContainer 'qa-mqtt-61') -ne 'qa-mqtt-61') { throw 'Container rejected.' }; $checks++
Get-ChildItem "$PSScriptRoot/*.ps1" | ForEach-Object {
    $errors = $null; $tokens = $null
    [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors) { throw "Syntax error in $($_.Name): $errors" }
}; $checks++
$qaId='123456abcdef'; $containerId='a'*64
$owned=[pscustomobject]@{Id=$containerId;Name="/vsqa-$qaId-db";Config=@{Labels=@{'org.vedasentio.qa'=$qaId;'org.vedasentio.qa.role'='db'}}}
Assert-QaContainerIdentity $owned $qaId db $containerId; $checks++
Assert-Rejected { Assert-QaContainerIdentity $owned 'abcdef123456' db $containerId }
Assert-Rejected { Assert-QaContainerIdentity $owned $qaId mqtt $containerId }
Assert-Rejected { Assert-QaContainerIdentity $owned $qaId db ('b'*64) }
$timestamp=[DateTime]::UtcNow
$process=[pscustomobject]@{ExecutablePath='C:\qa\backend.exe';CreationDate=$timestamp;CommandLine="C:\qa\backend.exe --qa-instance=$qaId"}
$backend=@{Path=$process.ExecutablePath;CreatedTicks=$timestamp.Ticks} | ConvertTo-Json | ConvertFrom-Json
Assert-QaBackendIdentity $process $backend $qaId; $checks++
Assert-Rejected { Assert-QaBackendIdentity $process $backend 'abcdef123456' }
$backend.CreatedTicks++
Assert-Rejected { Assert-QaBackendIdentity $process $backend $qaId }
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
try {
    $listener.Start(); $busyPort=$listener.LocalEndpoint.Port
    Assert-Rejected { Assert-QaPortFree $busyPort }
} finally { $listener.Stop() }
$previousHost=$env:DOCKER_HOST
try {
    $env:DOCKER_HOST='tcp://remote.invalid:2375'
    Assert-Rejected { Assert-QaLocalDocker }
} finally { $env:DOCKER_HOST=$previousHost }
if ($BackendPath) {
    $previous = $env:VEDASENTIO_API_PORT
    try {
        foreach ($value in @('0', '65536', '-1', 'abc', ' ', '999999999999999999999999')) {
            $env:VEDASENTIO_API_PORT = $value
            $output = & $BackendPath 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -or $output -notmatch 'VEDASENTIO_API_PORT must be' -or $output -match 'Backend starting') {
                throw 'Invalid configuration did not fail before service startup.'
            }; $checks++
        }
    } finally { $env:VEDASENTIO_API_PORT = $previous }
}
Write-Host "$checks QA checks passed"
