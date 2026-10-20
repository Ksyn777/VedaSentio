# Etap 14 - alarm dymu i zalania

## Cel

Domknięcie testów dla kolejnych typów zagrożeń obsługiwanych przez backend.

## Istniejąca logika produkcyjna

Backend już posiadał reguły:

- `smoke_detected` -> `smoke`, `critical`,
- `smoke_cleared` -> zakończenie alarmu dymu,
- `flood_detected` -> `flood`, `warning`,
- `flood_cleared` -> zakończenie alarmu zalania.

Obsługa nazw alarmów w Flutterze i tekstów FCM również już istniała.

## Co dodano

Rozszerzono `alarm_flow_test.cpp` o dwa osobne urządzenia:

- `smoke_sensor`,
- `flood_sensor`.

Dla obu typów test sprawdza utworzenie alarmu, severity, brak duplikatu, zakończenie i historię.

Dodano też test Fluttera:

- dym -> `critical` -> czerwony stan `ALARM`,
- zalanie -> `warning` -> stan `Ostrzeżenie`.
