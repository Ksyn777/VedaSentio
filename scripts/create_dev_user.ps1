$ErrorActionPreference = "Stop"

$required = @(
    "VEDASENTIO_DB_HOST",
    "VEDASENTIO_DB_PORT",
    "VEDASENTIO_DB_NAME",
    "VEDASENTIO_DB_USER",
    "VEDASENTIO_DB_PASSWORD",
    "VEDASENTIO_DATA_ENCRYPTION_KEY_B64",
    "VEDASENTIO_LOOKUP_HMAC_KEY_B64"
)

foreach ($name in $required) {
    if (-not [Environment]::GetEnvironmentVariable($name, "Process")) {
        throw "Missing environment variable: $name"
    }
}

$email = Read-Host "E-mail"
$firstName = Read-Host "Imie"
$lastName = Read-Host "Nazwisko"
$phone = Read-Host "Telefon"

$homeId = Read-Host "Home ID [home_001]"
if ([string]::IsNullOrWhiteSpace($homeId)) {
    $homeId = "home_001"
}

$role = Read-Host "Rola owner/caregiver/viewer [caregiver]"
if ([string]::IsNullOrWhiteSpace($role)) {
    $role = "caregiver"
}

$passwordSecure = Read-Host "Haslo (minimum 10 znakow)" -AsSecureString
$passwordConfirmSecure = Read-Host "Powtorz haslo" -AsSecureString

function Convert-SecureToPlain {
    param(
        [Parameter(Mandatory=$true)]
        [Security.SecureString]$SecureValue
    )

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
        $SecureValue
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

$password = Convert-SecureToPlain $passwordSecure
$passwordConfirm = Convert-SecureToPlain $passwordConfirmSecure

try {
    if ($password -ne $passwordConfirm) {
        throw "Hasla nie sa identyczne."
    }

    if ($password.Length -lt 10) {
        throw "Haslo musi miec minimum 10 znakow."
    }

    $env:VEDASENTIO_NEW_USER_EMAIL = $email
    $env:VEDASENTIO_NEW_USER_PASSWORD = $password
    $env:VEDASENTIO_NEW_USER_FIRST_NAME = $firstName
    $env:VEDASENTIO_NEW_USER_LAST_NAME = $lastName
    $env:VEDASENTIO_NEW_USER_PHONE = $phone
    $env:VEDASENTIO_NEW_USER_HOME_ID = $homeId
    $env:VEDASENTIO_NEW_USER_ROLE = $role

    & ".\backend\build\Debug\vedasentio_create_dev_user.exe"

    if ($LASTEXITCODE -ne 0) {
        throw "Nie udalo sie utworzyc uzytkownika."
    }
}
finally {
    Remove-Item Env:VEDASENTIO_NEW_USER_EMAIL -ErrorAction SilentlyContinue
    Remove-Item Env:VEDASENTIO_NEW_USER_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:VEDASENTIO_NEW_USER_FIRST_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:VEDASENTIO_NEW_USER_LAST_NAME -ErrorAction SilentlyContinue
    Remove-Item Env:VEDASENTIO_NEW_USER_PHONE -ErrorAction SilentlyContinue
    Remove-Item Env:VEDASENTIO_NEW_USER_HOME_ID -ErrorAction SilentlyContinue
    Remove-Item Env:VEDASENTIO_NEW_USER_ROLE -ErrorAction SilentlyContinue

    $password = $null
    $passwordConfirm = $null
}
