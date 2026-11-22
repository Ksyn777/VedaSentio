# Smoke test: MQTT -> PostgreSQL -> API (bez ESP32)

Ten test weryfikuje rzeczywisty zapis zdarzenia przez lokalny backend.
Nie wymaga fizycznej płytki ESP32 ani Firebase.

## Przygotowanie

1. Uruchom lokalny PostgreSQL, Mosquitto i backend C++ zgodnie z dokumentacją konfiguracji.
2. Migracje i database/dev_seed.sql stosuj tylko na **osobnej bazie testowej**.
3. Utwórz konto testowe mające dostęp do home_001.
4. W tym samym terminalu PowerShell ustaw dane MQTT i wykonaj:

   `.\scripts\login_api_dev.ps1`

   JWT jest zapisywany w pamięci PowerShell; nie kopiuj go do logów.

## Uruchomienie

Z katalogu głównego repozytorium:

```powershell
.\scripts\smoke_door_mqtt_api.ps1 -State opened
.\scripts\smoke_door_mqtt_api.ps1 -State closed
```

Można podać `-TimeoutSeconds 30`, jeśli środowisko odpowiada wolno.

Skrypt odczytuje największy dotychczasowy numer ID, publikuje zdarzenie
przez istniejący skrypt MQTT i sprawdza API przez maksymalnie 15 sekund.
Wynik PASS oznacza, że znaleziono **nowy** rekord dla home_001/door_001,
właściwego event_type i wartości logicznej. Przy błędzie API lub braku
rekordu zgłaszany jest błąd zamiast fałszywego sukcesu.

## Zakres i ograniczenia

- Wykonuj tylko w izolowanym środowisku testowym, ponieważ tworzy dane.
- Podczas pomiaru nie uruchamiaj równoległego publikatora dla door_001.
  Test identyfikuje rekord po nowym ID, urządzeniu, typie i wartości.
- Nie dowodzi działania interfejsu Flutter, Firebase, GPIO ani połączenia ESP32.
- GitHub Actions sprawdza **składnię** PowerShell; integracyjny smoke
  wymaga lokalnego Docker/Windows i uruchomionego backendu.
- 401: zaloguj się ponownie; 403: sprawdź rolę i przypisanie domu;
  brak nowego eventu: sprawdź logi backendu, brokera i PostgreSQL.
- Pełny odbiór Issue #29 wymaga dalszych scenariuszy; ESP32 dopiero na koniec.
