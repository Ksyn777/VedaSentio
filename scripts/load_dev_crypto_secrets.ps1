$ErrorActionPreference = "Stop"

$secretDirectory = Join-Path $env:APPDATA "VedaSentio"
$secretFile = Join-Path $secretDirectory "dev-crypto-secrets.json"

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

if (-not (Test-Path $secretFile)) {
    throw "Development crypto secrets do not exist. Run .\scripts\setup_dev_crypto_secrets.ps1 first."
}

$payload = Get-Content `
    -Path $secretFile `
    -Raw |
    ConvertFrom-Json

if ($payload.version -ne 1) {
    throw "Unsupported development secret format."
}

$env:VEDASENTIO_DATA_ENCRYPTION_KEY_B64 =
    Unprotect-Text $payload.data_encryption_key

$env:VEDASENTIO_LOOKUP_HMAC_KEY_B64 =
    Unprotect-Text $payload.lookup_hmac_key

Write-Host ""
Write-Host "[SECRETS] Development crypto keys loaded into this PowerShell process."
Write-Host "[SECRETS] Values were not printed."
Write-Host ""
