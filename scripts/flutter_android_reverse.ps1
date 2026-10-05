$ErrorActionPreference = "Stop"
Write-Host "[FLUTTER] Android localhost:8080 -> Windows localhost:8080"
adb devices
adb reverse tcp:8080 tcp:8080
if ($LASTEXITCODE -ne 0) { throw "adb reverse failed. Start an emulator or connect an Android device with USB debugging." }
Write-Host "[FLUTTER] Reverse tunnel ready. Backend may remain on 127.0.0.1:8080."
