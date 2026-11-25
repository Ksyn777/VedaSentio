# Shared safety checks for local QA. No services are started here.
function Get-QaApiBaseUrl {
    param([string]$Value = $env:VEDASENTIO_API_BASE_URL)
    if ($null -eq $Value -or $Value -eq '') { $Value = 'http://127.0.0.1:8080' }
    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -cne 'http' -or $uri.Host -notin @('127.0.0.1', 'localhost', '[::1]', '::1') -or
        $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -ne '/' -or
        $uri.Port -lt 1 -or $Value -match '\s') {
        throw 'QA API requires an HTTP loopback base URL without credentials, path, query or fragment.'
    }
    return $uri.GetLeftPart([UriPartial]::Authority)
}

function Get-QaMqttContainer {
    param([string]$Value = $env:VEDASENTIO_TEST_MQTT_CONTAINER)
    if ($null -eq $Value -or $Value -eq '') { return 'vedasentio-mqtt' }
    if ($Value -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$') { throw 'Invalid QA MQTT container name.' }
    return $Value
}

function Assert-QaDockerEndpoint {
    param([string]$Endpoint)
    if ($Endpoint -notmatch '^npipe:/{2,4}\./pipe/[a-zA-Z0-9_.-]+$') {
        throw 'QA requires a local Windows Docker named pipe; remote Docker is forbidden.'
    }
}

function Assert-QaLocalDocker {
    if ($env:DOCKER_HOST -or $env:DOCKER_TLS_VERIFY -or $env:DOCKER_CERT_PATH) {
        throw 'Remove Docker host/TLS overrides before local QA.'
    }
    $context = docker context show
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read Docker context.' }
    $endpoint = docker context inspect $context --format '{{.Endpoints.docker.Host}}'
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Docker context.' }
    Assert-QaDockerEndpoint $endpoint
    $os = docker info --format '{{.OSType}}'
    if ($LASTEXITCODE -ne 0 -or $os -ne 'linux') { throw 'Docker Desktop Linux engine is required.' }
}
