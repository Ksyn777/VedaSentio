$ErrorActionPreference = "Stop"

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

$env:VEDASENTIO_DATA_ENCRYPTION_KEY_B64 = New-RandomBase64Key
$env:VEDASENTIO_LOOKUP_HMAC_KEY_B64 = New-RandomBase64Key

Write-Host ""
Write-Host "[CRYPTO] Development keys generated for this PowerShell process."
Write-Host "[CRYPTO] Keys were NOT written to a file and are NOT printed."
Write-Host "[CRYPTO] They disappear when this terminal session ends."
Write-Host "[CRYPTO] Production will use a dedicated secret manager/KMS."
Write-Host ""
