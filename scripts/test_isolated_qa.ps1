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
