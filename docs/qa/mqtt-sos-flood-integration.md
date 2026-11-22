# Test integracyjny SOS i zalania — VedaSentio (#26)

## Co sprawdza automatycznie
Uruchomienie prawdziwego Mosquitto na loopback 127.0.0.1:28885 oraz osobnej, jednorazowej bazy PostgreSQL 17 `vedasentio_alarm_ci`. Kompilacja oryginalnych plików `MqttClient.cpp`, `SensorEventParser.cpp`, `Database.cpp` i `AlarmRepository.cpp` z testowym programem wyzwalającym kolejne scenariusze.

- MQTT `sos_pressed` zapisuje event i jeden alarm **critical**.
- Kolejny `sos_pressed` nie tworzy drugiego aktywnego alarmu, lecz aktualizuje ostatni event tego samego alarmu.
- `sos_resolved` rozwiązuje SOS i zachowuje historię alarmu.
- Nieznany event oraz `sos_pressed` z niewłaściwą wartością są odrzucane bez zapisu.
- `flood_detected` tworzy alarm **warning**, powtórzenie nie tworzy drugiego aktywnego alarmu.
- `flood_cleared` rozwiązuje alarm zalania i utrzymuje historię.
- Symulowana awaria wysyłki push nie usuwa alarmu w bazie danych: test oczekuje dwóch prób, po jednej dla SOS i zalania.

Do testu nie są ładowane rzeczywiste klucze, konta Firebase, baza użytkownika ani wiadomości prywatne. Broker słucha tylko na 127.0.0.1. `libpqxx 7.10.7` jest przypięta do konkretnego commita. Test odmawia uruchomienia na innej nazwie lub adresie bazy.

## Ograniczenia i odbiór fizyczny

Jest to prawdziwy test komunikacji MQTT i bazy PostgreSQL z symulowaną publikacją wiadomości oraz **testową implementacją powiadomień**, nie pełen end-to-end z przyciskiem i czujnikiem zalania na ESP32 ani telefonem Flutter. Ponowne dostarczenie tej samej publikacji w QoS 1 może zapisać kolejny rekord zdarzenia; test potwierdza brak drugiego aktywnego alarmu, nie gwarancję exactly-once.

Kryteria odbioru #26 wymagające sprzętu:
1. Naciśnij rzeczywisty przycisk SOS na ESP32: sprawdź event, alarm critical i widoczność w aplikacji.
2. Powtórz naciśnięcie: potwierdź brak drugiego aktywnego alarmu.
3. Wyzwól czujnik zalania: potwierdź alarm warning w bazie i na telefonie.
4. Usuń zalanie: potwierdź event `flood_cleared`, rozwiązanie alarmu i historię.
5. Wykonaj próbę niedostępności usługi push — alarm musi pozostać widoczny po odświeżeniu widoku.

Nie uznawaj zadania #26 za zakończone bez tych testów sprzętowych. Nie wykonuj ich na instalacji faktycznie używanej do opieki nad osobą.
