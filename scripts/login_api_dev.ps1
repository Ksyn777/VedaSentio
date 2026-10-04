$ErrorActionPreference = "Stop"

$email = Read-Host "E-mail"
$passwordSecure = Read-Host "Haslo" -AsSecureString

$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
    $passwordSecure
)

try {
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
        $pointer
    )

    $body = @{
        email = $email
        password = $password
    } | ConvertTo-Json

    $login = Invoke-RestMethod `
        -Method Post `
        -Uri "http://127.0.0.1:8080/api/auth/login" `
        -ContentType "application/json" `
        -Body $body

    $global:VEDASENTIO_ACCESS_TOKEN = $login.access_token

    Write-Host ""
    Write-Host "[API] Login OK."
    Write-Host "[API] Access token saved in `$global:VEDASENTIO_ACCESS_TOKEN."
    Write-Host "[API] Token value was not printed."
    Write-Host "[API] Expires in $($login.expires_in) seconds."
    Write-Host "[API] User id: $($login.user.id)"
    Write-Host ""
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
        $pointer
    )

    $password = $null
    $body = $null
}
