# VedaSentio — workflow pracy

## Start zadania

1. Przeczytaj Issue.
2. Sprawdź zależności.
3. Pobierz aktualny `master`.
4. Utwórz osobną gałąź.
5. Zmieniaj tylko pliki potrzebne do Issue.

## Nazwy gałęzi

- `feat/8-door-contact`
- `fix/16-mqtt-reconnect`
- `test/15-alarm-rules`
- `docs/28-readme-architecture`

## Commit

Commit ma opisywać jedną logiczną zmianę. Nie mieszaj np. zmian firmware z przypadkowym formatowaniem Fluttera.

## Pull Request

PR musi zawierać:
- `Refs #<issue>`,
- co zostało zmienione,
- jakie pliki/moduły ruszono,
- jakie testy naprawdę uruchomiono i ich wynik,
- czego nie udało się sprawdzić,
- jak użytkownik ma odebrać zmianę lokalnie,
- sekcję `Notatka do pracy`: **Co / Jak / Dlaczego / Test**.

Nie używaj `Closes #...` dopóki użytkownik nie zrobi lokalnego odbioru.

## Dziennik do pracy inżynierskiej

Zwykły PR kodowy nie zmienia `docs/thesis/ENGINEERING_LOG.md`. Dzięki temu kilka równoległych gałęzi nie powoduje konfliktów w jednym pliku.

Każdy istotny PR zawiera sekcję:

```text
## Notatka do pracy
Co:
Jak:
Dlaczego:
Test:
```

Po scaleniu zaakceptowaną treść dopisuje koordynator do `ENGINEERING_LOG.md`. Bezpośrednia edycja dziennika jest dozwolona dla zadań dokumentacyjnych, których zakresem jest sam dziennik.

## Po PR

- nie merge'uj automatycznie,
- nie zamykaj Issue,
- nie wdrażaj,
- czekaj na lokalny odbiór użytkownika.

## Gdy coś jest niejasne

Nie zgaduj reguły biznesowej, progu alarmowego, pinu sprzętowego ani sposobu wdrożenia. Opisz blokadę i wskaż, czego potrzeba do decyzji.
