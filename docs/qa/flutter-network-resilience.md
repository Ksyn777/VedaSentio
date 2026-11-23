# VedaSentio — awaria sieci, 401/403, retry i monitorowanie starych danych (#21)

## Zmiany
- `ApiClient` zamienia timeout, błędy gniazda sieciowego i `http.ClientException` na przewidywalne `ApiException` z komunikatem po polsku. Statusy HTTP **401 i 403 nie są zastępowane** błędem połączenia.
- `AuthService` pozwala w testach podać fikcyjny klient HTTP i pamięciowy magazyn tokenów. W produkcji nadal używa oryginalnych `ApiClient` i `TokenStorage`.
- `HomeDetailsScreen` zachowuje ostatnie poprawne dane po nieudanym odświeżaniu, ale pokazuje **Dane nieaktualne** zamiast mylącego oznaczenia monitoringu na żywo. Po prawidłowym retry oznaczenie znika.
- Brak nowego cache offline, nowych endpointów ani zmian zabezpieczeń API.

## Testy automatyczne
- `mobile/test/api_client_network_test.dart`: SocketException we wszystkich metodach, timeout, ClientException, HTTP 401/403 bez zmiany statusu oraz skuteczny retry na tej samej instancji.
- `mobile/test/auth_service_network_test.dart`: wylogowanie po 401, zachowanie sesji przy 403 i awarii sieci.
- `mobile/test/home_details_network_test.dart`: błąd pierwszego pobrania i retry, stale-data po awarii odświeżania i powrót po retry, 401/403 oraz komunikat po błędzie potwierdzenia alarmu.

## Odbiór ręczny
Na telefonie w środowisku testowym:
1. Zaloguj się, otwórz monitoring i wyłącz backend/sieć: po błędzie odświeżenia powinno pozostać stare zestawienie **z etykietą „Dane nieaktualne”**, a nie zielonym zapewnieniem, że stan jest aktualny.
2. Przywróć sieć i odśwież. Etykieta powinna powrócić do „Monitoring na żywo” dopiero po pobraniu danych.
3. Spróbuj potwierdzić alarm bez połączenia — wyświetli się komunikat błędu, bez potwierdzenia lokalnego.
4. Po 401 aplikacja powinna wrócić do logowania; po 403 zachować sesję i pokazać odmowę dostępu.
5. Sprawdź brak crasha przy timeout. Nie używaj tego systemu jako certyfikowanego systemu alarmowego.

Testy na fizycznym telefonie i prawdziwym backendzie są nadal do odbioru.