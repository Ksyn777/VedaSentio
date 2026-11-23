# Odbiór reconnect backendu — Refs #16

Zmiana przygotowana z master `5ad6a13` (PR #56 i #41). Nie przenosić całej
starej gałęzi PR #39: zawiera starsze wersje parsera, testów i CI.

## Działanie

Paho odpowiada za automatyczny reconnect z interwałem 1–30 sekund.
Pierwszy callback `connected()` jest pomijany: `start()` sam subskrybuje
i czeka na SUBACK. Każdy następny `connected()` zleca subskrypcję bez
oczekiwania. Flaga pierwszego połączenia jest atomowa, ponieważ callback
i kod startowy mogą działać na różnych wątkach. Nie dodano wątku ani pętli retry.

## Testy automatyczne

Po skonfigurowaniu backendu z zależnościami:

```powershell
cmake --build backend/build --config Debug
ctest --test-dir backend/build -C Debug --output-on-failure
```

`vedasentio_mqtt_reconnect_test` kompiluje produkcyjny `MqttClient.cpp`
z testowym transportem zamiast Paho. Sprawdza opcje reconnect, pojedynczą
subskrypcję startową z oczekiwaniem, dwukrotny reconnect, topic/QoS,
brak oczekiwania w callbacku i obsługę wyjątku subscribe. Nie używa bazy,
sieci, Firebase ani prawdziwych danych dostępowych. Osobny test parsera
pozostaje niezmieniony. Testowy nagłówek nie jest używany przez backend.

Wykonano lokalnie build MSVC Debug i CTest w tymczasowym projekcie:
parser oraz cykl MQTT 2/2 PASS. Przed zmianą test cyklu wykazał brak
reconnect. Tymczasowy build korzystał z nlohmann/json 3.11.3.
Pełnego buildu backendu i regresji PostgreSQL nie wykonano lokalnie.

## Odbiór z prawdziwym brokerem — nadal do wykonania

Na izolowanym środowisku testowym uruchomić backend z Mosquitto i bazą.
Użyć syntetycznego publikatora MQTT zamiast fizycznego ESP32.

1. Po pierwszym starcie i SUBACK opublikować poprawne zdarzenie; potwierdzić zapis.
2. Zatrzymać wyłącznie testowy broker. Backend ma pozostać uruchomiony.
3. Włączyć broker; poczekać na ponowną subskrypcję i opublikować nowe,
   rozróżnialne zdarzenie. Potwierdzić zapis bez restartu backendu.
4. Powtórzyć restart i publikację. Sprawdzić brak nadmiarowych rekordów
   w tym scenariuszu oraz brak duplikatów otwartego alarmu.
5. Opublikować niepoprawny payload i potwierdzić brak skutków w bazie.

Nie uruchamiać na bazie developerskiej użytkownika ani produkcyjnych kontach.
Nie zakładać odtworzenia wiadomości opublikowanych podczas awarii.
QoS 1 nie zapewnia exactly-once. Błąd początkowego połączenia nadal kończy
start backendu. Zlecenie subskrypcji po reconnect nie jest potwierdzeniem
SUBACK; asynchroniczna odmowa subskrypcji wymaga osobnej diagnostyki.

## Notatka do pracy

**Co:** reconnect MQTT backendu bez cofania parsera i regresji alarmów.
**Jak:** mechanizm Paho 1–30 s, rozdzielenie pierwszego subscribe od callbacku
reconnect, test klasy produkcyjnej z transportem testowym.
**Dlaczego:** prosty mechanizm biblioteki unika własnych wątków retry,
blokowania callbacku oraz podwójnego subscribe przy poprawnym starcie.
**Test:** lokalny MSVC/CTest 2/2 PASS; prawdziwy broker, PostgreSQL i pełne CI
pozostają do odbioru. Bez testów fizycznego ESP32.
