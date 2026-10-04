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

function Unprotect-Text {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProtectedText
    )

    $secure = ConvertTo-SecureString $ProtectedText

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
        $secure
    )

    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            $pointer
        )
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
            $pointer
        )
    }
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $secretDirectory |
    Out-Null

if ($ForceRotate) {
    if (Test-Path $secretFile) {
        Write-Warning "Rotating encryption keys makes existing encrypted development data unreadable unless it is re-encrypted first."
    }

    $dataKey = New-RandomBase64Key
    $lookupKey = New-RandomBase64Key
    $jwtKey = New-RandomBase64Key

    $payload = [ordered]@{
        version = 2
        data_encryption_key = Protect-Text $dataKey
        lookup_hmac_key = Protect-Text $lookupKey
        jwt_signing_key = Protect-Text $jwtKey
    }

    $payload |
        ConvertTo-Json |
        Set-Content `
            -Path $secretFile `
            -Encoding UTF8

    $env:VEDASENTIO_DATA_ENCRYPTION_KEY_B64 = $dataKey
    $env:VEDASENTIO_LOOKUP_HMAC_KEY_B64 = $lookupKey
    $env:VEDASENTIO_JWT_SIGNING_KEY_B64 = $jwtKey

    $dataKey = $null
    $lookupKey = $null
    $jwtKey = $null

    Write-Host ""
    Write-Host "[SECRETS] Development encryption and JWT keys rotated."
    Write-Host "[SECRETS] Secret values were not printed."
    Write-Host ""

    exit 0
}

if (-not (Test-Path $secretFile)) {
    $dataKey = New-RandomBase64Key
    $lookupKey = New-RandomBase64Key
    $jwtKey = New-RandomBase64Key

    $payload = [ordered]@{
        version = 2
        data_encryption_key = Protect-Text $dataKey
        lookup_hmac_key = Protect-Text $lookupKey
        jwt_signing_key = Protect-Text $jwtKey
    }

    $payload |
        ConvertTo-Json |
        Set-Content `
            -Path $secretFile `
            -Encoding UTF8

    $env:VEDASENTIO_DATA_ENCRYPTION_KEY_B64 = $dataKey
    $env:VEDASENTIO_LOOKUP_HMAC_KEY_B64 = $lookupKey
    $env:VEDASENTIO_JWT_SIGNING_KEY_B64 = $jwtKey

    $dataKey = $null
    $lookupKey = $null
    $jwtKey = $null

    Write-Host ""
    Write-Host "[SECRETS] Development encryption and JWT keys created."
    Write-Host "[SECRETS] Protected with Windows DPAPI for the current Windows user."
    Write-Host "[SECRETS] Stored outside the repository:"
    Write-Host "[SECRETS] $secretFile"
    Write-Host "[SECRETS] Secret values were not printed."
    Write-Host ""

    exit 0
}

$existing = Get-Content `
    -Path $secretFile `
    -Raw |
    ConvertFrom-Json

if (
    -not $existing.data_encryption_key -or
    -not $existing.lookup_hmac_key
) {
    throw "Existing secret file is invalid."
}

$dataKey = Unprotect-Text $existing.data_encryption_key
$lookupKey = Unprotect-Text $existing.lookup_hmac_key

if (-not $existing.jwt_signing_key) {
    $jwtKey = New-RandomBase64Key

    $payload = [ordered]@{
        version = 2
        data_encryption_key = $existing.data_encryption_key
        lookup_hmac_key = $existing.lookup_hmac_key
        jwt_signing_key = Protect-Text $jwtKey
    }

    $payload |
        ConvertTo-Json |
        Set-Content `
            -Path $secretFile `
            -Encoding UTF8

    Write-Host ""
    Write-Host "[SECRETS] Existing development encryption keys preserved."
    Write-Host "[SECRETS] A new JWT signing key was added."
}
else {
    $jwtKey = Unprotect-Text $existing.jwt_signing_key

    Write-Host ""
    Write-Host "[SECRETS] Existing development encryption and JWT keys found."
    Write-Host "[SECRETS] No keys were rotated."
}

$env:VEDASENTIO_DATA_ENCRYPTION_KEY_B64 = $dataKey
$env:VEDASENTIO_LOOKUP_HMAC_KEY_B64 = $lookupKey
$env:VEDASENTIO_JWT_SIGNING_KEY_B64 = $jwtKey

$dataKey = $null
$lookupKey = $null
$jwtKey = $null

Write-Host "[SECRETS] Keys loaded into this PowerShell process."
Write-Host "[SECRETS] Secret values were not printed."
Write-Host ""
