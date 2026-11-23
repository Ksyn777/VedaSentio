# Smoke SOS przez MQTT i autoryzowane API

Test z zadania #29 sprawdza syntetyczne SOS w lokalnych usługach VedaSentio:
Mosquitto → backend C++ → PostgreSQL → REST API. Używa istniejącego
publikatora `mqtt_test_event.ps1`.

## Przygotowanie w Windows 11

1. Otwórz PowerShell 7 (`pwsh`) w katalogu głównym repozytorium.
2. Zgodnie z [quickstartem](../../README.md) przygotuj osobną, pustą bazę
   testową z migracjami i `database/dev_seed.sql`. Skonfiguruj backend tak,
   aby wskazywał właśnie tę bazę i lokalny testowy kontener
   `vedasentio-mqtt`. API ma nasłuchiwać na `127.0.0.1:8080`. Sprawdź
   konfigurację procesu backendu przed jego startem i upewnij się, że
   `GOOGLE_APPLICATION_CREDENTIALS` nie jest ustawione. Skrypt sam nie może
   odczytać konfiguracji bazy lub Firebase z procesu backendu.
3. Utwórz fikcyjne konto z dostępem do `home_001`. Seed rejestruje tam
   aktywne urządzenie `sos_001` typu `sos_button`. Na czas testu tylko ten
   skrypt może publikować SOS dla tego urządzenia. Nie podłączaj sprzętu
   ani innych publikatorów do jego topicu i nie potwierdzaj alarmu w UI.
4. Ustaw dane logowania testowego brokera w bieżącej sesji jak w quickstarcie.
   Publikator może też poprosić o hasło interaktywnie. Zaloguj się do API
   i uruchom test w tym samym terminalu:

   ```powershell
   .\scripts\login_api_dev.ps1
   .\scripts\smoke_sos_mqtt_api.ps1 -ConfirmIsolatedEnvironment -TimeoutSeconds 15
   ```

Przełącznik potwierdza świadomą zgodę na trwały zapis danych testowych
w osobnej bazie. JWT pozostaje w pamięci bieżącego terminala.

## Odczyt wyniku

`PASS` oznacza, że API potwierdziło trzy nowe zdarzenia i cały cykl jednego
alarmu `critical`: otwarcie, aktualizację bez drugiego otwartego alarmu
i rozwiązanie z zachowaniem historii. Skrypt porównuje ID, dom,
urządzenie, typ, wartość logiczną i czas UTC każdej publikacji. Sprawdza
`source_event_id` oraz `last_event_id` alarmu. Stan `acknowledged` blokuje
start tak samo jak `active`.

- **HTTP 401 lub 403** — zaloguj się ponownie lub sprawdź przypisanie domu.
- **API nie odpowiada / brak urządzenia** — sprawdź port 8080, działanie
  backendu, wskazaną bazę oraz seed.
- **Istnieje otwarty alarm** — użyj świeżego środowiska testowego. Skrypt
  zatrzymuje się przed publikacją i pozostawia istniejący alarm bez zmian.
- **Timeout / stan alarmu zmienił się poza testem** — sprawdź logi testowego
  brokera i backendu oraz historię w API. Powtórz w osobnym środowisku
  bez współbieżnych publikacji. `-TimeoutSeconds` określa limit odpytywania
  na etap (1–60 s, domyślnie 15 s).

Po przerwaniu skrypt nie wysyła zdarzenia sprzątającego. Rekordy oraz
ewentualny otwarty alarm utworzone przez wcześniejsze etapy pozostają
w bazie. Kontrole przed publikacją ograniczają ryzyko współbieżności,
ale API nie zapewnia transakcji obejmującej odczyt i publikację MQTT.
Korelacja po czasie nie odróżni celowo identycznej publikacji. Przy QoS 1
powtórne dostarczenie może zapisać więcej niż jeden rekord zdarzenia.

CI sprawdza składnię PowerShell. Pełny test wymaga lokalnego odbioru
z wymienionymi usługami. Test nie obejmuje ESP32, Fluttera ani Firebase
i stanowi tylko jeden scenariusz zadania #29.
