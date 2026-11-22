# VedaSentio — potwierdzanie alarmów i szczegóły Flutter (#19)

## Zakres i zależności
Ta gałąź jest oparta na PR #45 (obsługa błędów sieci Flutter); **nie jest jeszcze scalona do master**. Istniejące ekrany pozostają w użyciu, bez przebudowy interfejsu.

### Zmiany
- Po pomyślnym POST potwierdzającym alarm aplikacja czeka na starszy, ewentualnie trwający GET monitoringu, po czym **wymusza nowy odczyt**. Stare dane nie mogą zostawić przycisku „Potwierdź alarm” widocznego po udanym potwierdzeniu.
- Dodatkowa ochrona stanu: akcja uruchamiana jest tylko, gdy alarm nadal ma status `active` i rolę `owner` lub `caregiver`. Dla `acknowledged` i `resolved` nie wysyłamy kolejnych POST.
- Współdzielenie pojedynczego trwającego odczytu między odświeżeniami (bez równoległych GET dla jednego widoku).
- Testy ekranów obejmują role `owner`, `caregiver`, `viewer`, stany `active`, `acknowledged`, `resolved`, żądanie 401 i 403, podwójne kliknięcie, ponowny odczyt po zapisie i konflikt ze starszym automatycznym odświeżaniem.
- Testy szczegółów: typ, severity, urządzenie, czas, potwierdzenie i zachowana historia.

## Granice bezpieczeństwa
Ukrycie przycisku u `viewer` **nie jest mechanizmem autoryzacji**. Backend musi niezależnie zwracać 403 na ręcznie wysłany POST. Taki przypadek obejmuje test API w PR #44; ostatecznie oba PR wymagają wspólnego odbioru.

Testy korzystają z fikcyjnej implementacji `AuthService`. **Nie dowodzą** działania urządzenia fizycznego, komunikatów Firebase, realnej sieci ani połączenia Flutter z produkcyjnym API. Kod nie uruchamia wdrożenia, nie zmienia sekretów, uprawnień serwera ani bazy.

## Odbiór końcowy
Na telefonie po uruchomieniu testowego backendu:
1. Zaloguj `owner` i `caregiver`, otwórz aktywny alarm, potwierdź, sprawdź zmianę statusu i odświeżenie.
2. Zaloguj `viewer`: przycisku nie ma, a ręczny POST z tym JWT daje 403.
3. Sprawdź alarm wcześniej potwierdzony i zakończony: brak ponownego potwierdzenia.
4. Uruchom w tle odświeżenie, potwierdź alarm i zweryfikuj, że stary GET nie przywraca przycisku.
5. Przy błędzie sieci lub wygasłej sesji sprawdź czytelny komunikat i brak fałszywego sukcesu.
6. Sprawdź status na drugim urządzeniu i w PostgreSQL.

Nie zamykać zadania #19 bez odbioru na telefonie i z prawdziwym API.
