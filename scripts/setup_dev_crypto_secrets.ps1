param(
    [switch]$ForceRotate
)

$ErrorActionPreference = "Stop"

$secretDirectory = Join-Path $env:APPDATA "VedaSentio"
$secretFile = Join-Path $secretDirectory "dev-crypto-secrets.json"

function New-RandomBase64Key {
    param(
        [int]$Length = 32
    )

    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    try {
        $rng.GetBytes($bytes)
    }
    finally {
        $rng.Dispose()
    }

    return [Convert]::ToBase64String($bytes)
}

function Protect-Text {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PlainText
    )

    $secure = ConvertTo-SecureString `
        -String $PlainText `
        -AsPlainText `
        -Force

    return ConvertFrom-SecureString `
        -SecureString $secure
}

if ((Test-Path $secretFile) -and (-not $ForceRotate)) {
    Write-Host "[SECRETS] Existing protected development keys found."
    Write-Host "[SECRETS] Nothing was changed."
    Write-Host "[SECRETS] Use .\scripts\load_dev_crypto_secrets.ps1 to load them."
    exit 0
}

if ($ForceRotate -and (Test-Path $secretFile)) {
    Write-Warning "Rotating keys makes data encrypted with the previous keys unreadable unless it is re-encrypted first."
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $secretDirectory |
    Out-Null

$dataKey = New-RandomBase64Key
$lookupKey = New-RandomBase64Key

$payload = [ordered]@{
    version = 1
    data_encryption_key = Protect-Text $dataKey
    lookup_hmac_key = Protect-Text $lookupKey
}

$payload |
    ConvertTo-Json |
    Set-Content `
        -Path $secretFile `
        -Encoding UTF8

$env:VEDASENTIO_DATA_ENCRYPTION_KEY_B64 = $dataKey
$env:VEDASENTIO_LOOKUP_HMAC_KEY_B64 = $lookupKey

$dataKey = $null
$lookupKey = $null

Write-Host ""
Write-Host "[SECRETS] Development crypto keys created."
Write-Host "[SECRETS] Protected with Windows DPAPI for the current Windows user."
Write-Host "[SECRETS] Stored outside the repository:"
Write-Host "[SECRETS] $secretFile"
Write-Host "[SECRETS] Keys were also loaded into this PowerShell process."
Write-Host "[SECRETS] Secret values were not printed."
Write-Host ""
