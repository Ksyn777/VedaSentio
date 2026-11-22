# VedaSentio — dziennik techniczny do pracy inżynierskiej

Ten plik zbiera krótkie informacje potrzebne później do opisania projektu w pracy. Nie jest instrukcją użytkownika. Wpisy mają odpowiadać na cztery pytania: **co zrobiono, jak to działa, dlaczego tak zrobiono i jak to sprawdzono**.

## 1. Założenie systemu

VedaSentio jest systemem IoT wspomagającym opiekę nad osobą starszą lub wymagającą nadzoru w domu. Urządzenia z ESP32 zbierają zdarzenia z czujników, a opiekun może obserwować stan domu i alarmy w aplikacji mobilnej.

System nie zastępuje certyfikowanych systemów medycznych ani alarmowych.

## 2. Architektura

Przepływ danych:

`sensor -> ESP32 -> Wi-Fi -> MQTT/Mosquitto -> backend C++ -> PostgreSQL -> REST API -> Flutter`

Główne technologie:
- **ESP32 + Arduino/PlatformIO** — obsługa fizycznych czujników i wysyłanie zdarzeń,
- **MQTT + Eclipse Mosquitto** — lekki protokół komunikacji urządzeń z backendem,
- **C++20** — backend odbierający zdarzenia, obsługujący alarmy i API,
- **PostgreSQL** — trwały zapis urządzeń, zdarzeń, użytkowników i alarmów,
- **Flutter** — aplikacja mobilna opiekuna,
- **Firebase Cloud Messaging** — opcjonalne powiadomienia push o nowych alarmach.

Topic urządzeń:
`vedasentio/{home_id}/{device_id}/event`

Przykładowe zdarzenie:
`{"timestamp":"2026-10-22T08:14:04Z","event_type":"heartbeat","value":true}`

## 3. Dotychczas zrealizowane elementy

### Backend
- połączenie z PostgreSQL,
- odbiór zdarzeń przez MQTT,
- walidacja struktury topicu i podstawowych pól JSON,
- zapis zdarzeń sensorów,
- heartbeat i aktualizacja `last_seen`,
- wykrywanie urządzenia offline,
- alarmy dla SOS, dymu, CO, gazu i zalania,
- REST API z JWT i kontrolą dostępu do gospodarstwa,
- potwierdzanie alarmów,
- integracja z FCM bez uzależniania zapisu alarmu od powodzenia push.

### ESP32
Firmware pierwszego urządzenia `door_001` został podzielony na proste moduły:
- `DoorSensor` — odczyt kontaktronu i debounce,
- `NetworkManager` — Wi-Fi i MQTT,
- `TimeService` — synchronizacja NTP i timestamp UTC,
- `EventPublisher` — wspólne tworzenie i publikacja zdarzeń.

Kontaktron używa GPIO19 z `INPUT_PULLUP`. Zdarzenie jest uznawane za potwierdzone dopiero po udanej publikacji MQTT.

### Flutter
Aplikacja posiada:
- logowanie i odtwarzanie sesji,
- listę gospodarstw,
- monitoring urządzeń,
- historię zdarzeń i alarmów,
- szczegóły alarmu,
- potwierdzanie alarmu przez uprawnioną rolę,
- rejestrację tokena FCM,
- obsługę wejścia do alarmu po kliknięciu powiadomienia.

## 4. Ważne decyzje projektowe

### MQTT zamiast ciągłego HTTP z ESP32
MQTT dobrze pasuje do małych urządzeń IoT, ponieważ pozwala wysyłać krótkie komunikaty i oddziela urządzenie od szczegółów implementacji backendu.

### Heartbeat
ESP32 wysyła cykliczny heartbeat. Backend zapisuje czas ostatniej komunikacji i dzięki temu może wykryć urządzenie, które przestało odpowiadać.

### Debounce kontaktronu
Fizyczny styk może w krótkim czasie kilka razy zmienić stan. Firmware akceptuje zmianę dopiero po okresie stabilności, aby jedno otwarcie drzwi nie tworzyło kilku zdarzeń.

### Rozdzielenie firmware na małe moduły
Kod nie został rozbudowany o ciężki framework. Podział na kilka małych plików ułatwia zrozumienie odpowiedzialności każdego elementu i późniejsze dodawanie sensorów.

### Alarm zapisujemy niezależnie od push
Powiadomienie mobilne jest dodatkiem. Awaria Firebase nie może spowodować utraty alarmu w bazie.

### Sekrety poza repo
Hasła MQTT, bazy i klucze kryptograficzne nie są częścią kodu źródłowego. Repo przechowuje tylko konfigurację przykładową.

## 5. Potwierdzone testy wykonane dotychczas

- fizyczne ESP32 połączyło się z Wi-Fi,
- ESP32 połączyło się z brokerem Mosquitto,
- NTP zwróciło poprawny czas,
- heartbeat przeszedł ścieżkę ESP32 -> MQTT -> backend -> PostgreSQL,
- backend zaktualizował `last_seen` urządzenia.

Test fizycznego `door_opened/door_closed` oraz kolejne sensory wymagają ponownego odbioru na laptopie i prawdziwym ESP32.

---

# Rejestr zmian

## 2026-11-22 — uporządkowanie pracy nad repo
**Co:** utworzono backlog GitHub, EPIC-i, małe TASK-i, Definition of Done oraz zasady pracy z Codexem.

**Jak:** zastosowano model `1 TASK = 1 branch = 1 PR`, z osobnym odbiorem i zakazem automatycznego merge/deploy dla agentów.

**Dlaczego:** małe zmiany są łatwiejsze do sprawdzenia, cofnięcia i wyjaśnienia podczas obrony.

**Test/odbiór:** zmiana organizacyjna i dokumentacyjna; nie zmienia kodu wykonawczego.

---

## Szablon kolejnego wpisu

### YYYY-MM-DD — nazwa zmiany
**Co:**  
**Jak:**  
**Dlaczego:**  
**Test/odbiór:**  
