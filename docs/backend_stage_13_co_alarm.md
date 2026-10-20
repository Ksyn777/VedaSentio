# Etap 13 - obsługa alarmu CO

## Cel

Zweryfikowanie pełnego przepływu alarmu tlenku węgla.

Produkcja już posiadała reguły:
- `co_detected` -> alarm `co`, poziom `critical`,
- `co_cleared` -> zakończenie alarmu `co`.

Firebase Push Notification Service również posiadał gotowy tytuł i treść powiadomienia dla alarmu CO, a model Fluttera posiadał etykietę `Tlenek węgla`.

## Co dodano

Rozszerzono test backendu o osobne urządzenie `co_sensor`.

Test sprawdza:
1. utworzenie krytycznego alarmu po `co_detected`,
2. brak drugiego aktywnego alarmu po ponownym `co_detected`,
3. zakończenie alarmu po `co_cleared`,
4. zachowanie zakończonego alarmu w historii.

Dodano również test Fluttera sprawdzający etykietę `Tlenek węgla`, poziom `Krytyczny` i przejście głównego statusu domu do poziomu `ALARM`.

Nie dodawano specjalnej reguły CO do `AlarmStatusService`, ponieważ serwis celowo reaguje ogólnie na `severity == critical`.
