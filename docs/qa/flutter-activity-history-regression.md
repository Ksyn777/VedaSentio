# VedaSentio — regresja Aktywności i Historii alarmów (#20)

## Stan zastany
Ekrany już pobierają historię z API, obsługują filtr dat, poziom alarmu i wiele gospodarstw. Nie dokładamy nowych filtrów, animacji ani danych demonstracyjnych.

## Poprawka
Każde pobranie listy otrzymuje numer generacji. Wynik HTTP można zastosować tylko wtedy, gdy widok nadal istnieje, a generacja odpowiada ostatniemu żądaniu. To dotyczy zarówno sukcesu, błędu 403, nieoczekiwanego wyjątku, jak i 401 (starsza odpowiedź nie może wylogować użytkownika po przełączeniu na inny dom).

Przy wyborze nowego gospodarstwa czyścimy dane poprzedniego domu, pokazujemy ładowanie i pobieramy nowe rekordy. W Aktywności zachowujemy filtr daty odpowiedni dla wybranego gospodarstwa. Podział na Dzisiaj/Wczoraj porównuje daty kalendarzowe zamiast różnicy liczby pełnych godzin, co usuwa błąd na przejściu czasu letniego/zimowego.

## Automatyczne testy widgetowe
- Aktywność: etykiety po polsku dla drzwi, SOS i zalania; ukrycie heartbeat; filtrowanie po dacie; brak wyników i brak gospodarstw; szybkie przełączanie domów przy opóźnionym starym GET; stary HTTP 401 i mały ekran.
- Historia: alarmy SOS, zalanie i offline; filtrowanie krytyczne/ostrzeżenia; pusty filtr i brak gospodarstw; otwarcie szczegółów; szybkie przełączanie domów, stara odpowiedź 403 i mały ekran 320px.
- Testowe obiekty `AuthService`, dane fikcyjne — bez sekretów, rzeczywistych danych pacjentów i urządzeń.
- `flutter analyze --no-fatal-infos` i `flutter test` w standardowym GitHub Actions.

## Odbiór
- Uruchomić aplikację z testowym API i bazą (bez ESP32).
- Szybko przełączyć A → B podczas wolnego żądania A: dane A nie mogą pojawić się pod nazwą B.
- Sprawdzić dotykowe sterowanie filtrami, format daty, scroll i brak overflow na małym telefonie.
- Na 401 z bieżącego żądania aplikacja ma kończyć sesję, 403 ma pozostać odmową dostępu.
- Na brak sieci lista ma wyświetlić komunikat, a nie stale dane udające aktualne.
- Potwierdzić kontrakt API i testy na emulatorze. Fizyczne czujniki i ESP32 pozostają **ostatnim etapem**.

## Wzorzec UI
Kontynuujemy neutralny, funkcjonalny kierunek z Figma: https://www.figma.com/design/MXDiWHTFJzgCl3L7x4qeHr. Nie dokonujemy w tej zmianie kosmetycznego redesignu obu ekranów przed potwierdzeniem ich działania; czytelność i brak przelewania tekstów mają pierwszeństwo.

Testy widgetowe nie oznaczają zakończonego odbioru na fizycznym telefonie.
