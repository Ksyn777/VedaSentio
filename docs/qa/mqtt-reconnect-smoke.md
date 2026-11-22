# VedaSentio — test MQTT po awarii brokera (#27)

## Zakres automatycznego testu

Workflow `Isolated MQTT reconnect smoke` działa na Ubuntu 24.04. Uruchamia osobny broker Mosquitto wyłącznie na `127.0.0.1:28883`, bez trwałego przechowywania danych, a następnie kompiluje **oryginalne** `MqttClient.cpp` i `SensorEventParser.cpp` z repozytorium.

Baza PostgreSQL i powiadomienia push są zastąpione pamięcią testową. Nie są używane rzeczywiste konta, urządzenia ani hasła. Skrypt:

1. Wysyła poprawne `door_opened` i wymaga jednego zapisanego zdarzenia.
2. Wysyła niepoprawne `door_closed` (string zamiast bool) i upewnia się, że nie zmienia stanu.
3. Zatrzymuje broker, wymaga powiadomienia o utracie połączenia.
4. Uruchamia broker ponownie i wymaga nowego żądania subskrypcji z callbacku Paho.
5. Wysyła `door_closed`, wymaga dokładnie dwóch zdarzeń łącznie — bez duplikatów.

To **test integracji MQTT z testowym magazynem danych**, a nie pełny E2E z PostgreSQL, ESP32 i aplikacją Flutter.

## Uruchomienie lokalne na Linuksie

Z katalogu głównego repozytorium:

~~~bash
sudo apt-get install -y g++ libpaho-mqttpp-dev libpaho-mqtt-dev nlohmann-json3-dev mosquitto mosquitto-clients
bash scripts/test_mqtt_reconnect_linux.sh
~~~

Port można nadpisać tylko w tym teście zmienną `VEDASENTIO_SMOKE_PORT`. Nie podawać portu rzeczywistego brokera.

## Odbiór sprzętowy pozostający do wykonania

Na osobnej, izolowanej bazie i lokalnym Mosquitto, z fizycznym ESP32:

- Udokumentuj pierwszy heartbeat oraz otwarcie/zamknięcie drzwi w bazie testowej.
- Odłącz ESP32/Wi-Fi na ponad dwie minuty: urządzenie powinno przejść w stan offline, przy maksymalnie jednym aktywnym alarmie offline.
- Po powrocie Wi-Fi i heartbeat alarm offline powinien zostać rozwiązany; sprawdź historię.
- Zatrzymaj i uruchom Mosquitto przy działającym backendzie, potem wyślij **nowe** zdarzenie. Zweryfikuj, że zapis jest pojedynczy i backend nie wymaga ręcznego restartu.
- Oddzielnie sprawdź start backendu, gdy broker od początku jest nieosiągalny: aktualny kod może zakończyć proces; to ograniczenie PR #39, nie zaliczaj tego scenariusza.
- Zapisz wynik i wersję firmware. Nie traktuj samej kompilacji firmware jako testu fizycznego.

**Odbiór #27 pozostaje niepełny**, dopóki te scenariusze nie zostaną rzeczywiście wykonane.
