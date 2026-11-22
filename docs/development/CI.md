# GitHub Actions CI

Workflow `.github/workflows/ci.yml` uruchamia się dla pull requestów, pushy do `master` oraz ręcznie.

## Backend C++
- runner: Windows,
- vcpkg jest przypięty do baseline z `vcpkg.json`,
- wykonywany jest pełny build backendu,
- uruchamiany jest test warstwy kryptograficznej,
- uruchamiany jest CTest dla testów zarejestrowanych w CMake.

## Flutter
- runner: Linux,
- pobierany jest oficjalny Flutter stable,
- `flutter pub get`,
- `flutter analyze`,
- `flutter test`.

## Firmware ESP32
- runner: Linux,
- instalowany jest PlatformIO,
- CI kopiuje `secrets.example.h` jako tymczasowy `secrets.h`,
- wykonywany jest tylko `pio run`.

## Czego CI nie sprawdza

CI nie zastępuje:
- fizycznego testu ESP32,
- sprawdzenia GPIO i czujników,
- testu Wi-Fi i MQTT w sieci domowej,
- testu aplikacji na prawdziwym telefonie,
- testów integracyjnych wymagających lokalnej bazy PostgreSQL i rzeczywistych usług.

Te elementy są odbierane osobno na laptopie i urządzeniach.
