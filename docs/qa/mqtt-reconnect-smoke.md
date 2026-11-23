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


## Automatyczny test z prawdziwą bazą PostgreSQL

Drugi job `PostgreSQL + MQTT offline alarm recovery` w tym samym workflow uruchamia:
- osobny kontener PostgreSQL 17 z **wyłącznie testową** bazą `vedasentio_mqtt_ci`,
- prawdziwe implementacje `Database.cpp`, `AlarmRepository.cpp`, `MqttClient.cpp` i `SensorEventParser.cpp`,
- przypiętą do konkretnego commita poprawioną bibliotekę libpqxx 7.10.7,
- osobny Mosquitto na `127.0.0.1:28884` (bez zewnętrznej publikacji), bez Firebase.

Test uruchamia rzeczywiste zapytania do PostgreSQL. Sprawdza kolejno: heartbeat aktualizuje `last_seen` i nie tworzy rekordu zdarzenia; błędny JSON nie zmienia stanu urządzenia; ustawienie `last_seen` na trzy minuty wstecz powoduje stan offline; dwa wywołania wykrycia offline tworzą maksymalnie **jeden aktywny** alarm; restart Mosquitto i nowy heartbeat automatycznie przywracają stan online oraz rozwiązują alarm; po **drugim z rzędu restarcie brokera** prawidłowe `door_opened` trafia do bazy dokładnie raz.

Jest to test integracyjny **prawdziwej bazy i brokera**, lecz sztucznie wywołuje otwarcie alarmu offline (harmonogram `main.cpp` nie jest uruchamiany). Nie potwierdza jeszcze działania fizycznego ESP32, API ani Fluttera. Test zakłada lokalną bazę o nazwie `vedasentio_mqtt_ci` i odmawia użycia innego hosta lub nazwy bazy, aby przypadkowo nie zmodyfikować danych użytkownika.

## Odbiór sprzętowy pozostający do wykonania

Na osobnej, izolowanej bazie i lokalnym Mosquitto, z fizycznym ESP32:

- Udokumentuj pierwszy heartbeat oraz otwarcie/zamknięcie drzwi w bazie testowej.
- Odłącz ESP32/Wi-Fi na ponad dwie minuty: urządzenie powinno przejść w stan offline, przy maksymalnie jednym aktywnym alarmie offline.
- Po powrocie Wi-Fi i heartbeat alarm offline powinien zostać rozwiązany; sprawdź historię.
- Zatrzymaj i uruchom Mosquitto przy działającym backendzie, potem wyślij **nowe** zdarzenie. Zweryfikuj, że zapis jest pojedynczy i backend nie wymaga ręcznego restartu.
- Oddzielnie sprawdź start backendu, gdy broker od początku jest nieosiągalny: aktualny kod może zakończyć proces; to ograniczenie PR #39, nie zaliczaj tego scenariusza.
- Zapisz wynik i wersję firmware. Nie traktuj samej kompilacji firmware jako testu fizycznego.

**Odbiór #27 pozostaje niepełny**, dopóki te scenariusze nie zostaną rzeczywiście wykonane.

## Granice potwierdzenia braku duplikatów

Testy sprawdzają, że **pojedynczo opublikowana** wiadomość jest zapisywana dokładnie raz oraz że wielokrotne sprawdzenie offline nie tworzy kolejnych aktywnych alarmów. MQTT przy QoS 1 dopuszcza ponowne dostarczenie komunikatu. Obecny kontrakt nie zawiera trwałego identyfikatora zdarzenia, więc system **nie zapewnia jeszcze deduplikacji dwóch oddzielnie dostarczonych identycznych publikacji**. Nie opisujemy tej właściwości jako „exactly once”.

Test PostgreSQL wysyła także komunikaty z nieznanego i nieaktywnego urządzenia oraz błędnym timestampem; muszą zostać odrzucone bez zapisu zdarzenia czy zmiany stanu.
