$ErrorActionPreference = "Stop"

$firebaseCredentialsPath =
    Join-Path `
        $env:APPDATA `
        "VedaSentio\firebase-service-account.json"

if (-not (Test-Path $firebaseCredentialsPath))
{
    Write-Host ""
    Write-Host "[FIREBASE] Brak pliku konta uslugi:"
    Write-Host $firebaseCredentialsPath
    Write-Host ""
    Write-Host "[FIREBASE] Najpierw zapisz tam klucz JSON z Firebase Console."
    throw "Firebase service account file not found."
}

$env:GOOGLE_APPLICATION_CREDENTIALS =
    $firebaseCredentialsPath

Write-Host ""
Write-Host "[FIREBASE] Server credentials path loaded."
Write-Host "[FIREBASE] Secret content was not printed."
