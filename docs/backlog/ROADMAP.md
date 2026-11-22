# VedaSentio — ROADMAP MVP

Źródło prawdy dla aktualnej kolejności: GitHub Issue #30.

## Priorytet P0

### Etap 1 — pierwszy kompletny sensor
1. #8 Kontaktron drzwi
2. #12 Konfiguracja firmware
3. #14 Walidacja MQTT
4. #15 Testy reguł alarmów
5. #23 Bezpieczna konfiguracja developerska

### Etap 2 — fizyczne alarmy i odporność
6. #9 SOS
7. #10 Zalanie
8. #13 Reconnect ESP32
9. #16 Reconnect backendu MQTT
10. #17 API domu/urządzeń/zdarzeń/alarmów

### Etap 3 — aplikacja mobilna
11. #18 Monitoring domu
12. #19 Szczegóły i potwierdzanie alarmu
13. #21 Błędy/brak sieci/smoke UI

### Etap 4 — integracja
14. #24 CI
15. #25 E2E drzwi
16. #26 E2E SOS i zalanie
17. #27 E2E offline/reconnect

### Etap 5 — obrona
18. #28 README/architektura/MQTT
19. #29 Scenariusz demonstracyjny

## Priorytet P1
- #11 dym/CO/gaz,
- #20 historia i aktywność,
- #22 Firebase push end-to-end.

## Praca równoległa

Codex najlepiej:
- #14–#17,
- #18–#21,
- #23–#24,
- #28.

Sprzęt / ręczny odbiór:
- #8–#13,
- #25–#27,
- część #22 i #29.

Nie uruchamiaj dwóch agentów na tej samej gałęzi. Przy pracy równoległej używaj osobnych branchy/worktree.
