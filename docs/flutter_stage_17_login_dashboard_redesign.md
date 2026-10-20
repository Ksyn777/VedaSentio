# Etap 17 - ujednolicenie interfejsu aplikacji

## Cel

Ujednolicenie wyglądu ekranu logowania, listy gospodarstw i ekranu szczegółów domu.
Zmiany dotyczą warstwy prezentacji. Logika logowania, JWT, API, alarmów, auto-refresh i powiadomień pozostaje bez zmian.

## Zmiany

- ekran logowania otrzymał jasne, ciepłe tło i zaokrągloną kartę formularza,
- lista gospodarstw korzysta z tego samego stylu co ekran monitoringu,
- zachowano przejście do istniejącego `HomeDetailsScreen`,
- przycisk potwierdzenia alarmu używa koloru zależnego od poziomu alarmu:
  - critical - czerwony,
  - warning - pomarańczowy,
- `dev_seed.sql` zapisano jako UTF-8 z BOM, aby Windows PowerShell poprawnie przekazywał polskie znaki do PostgreSQL.

## Założenia wizualne

Interfejs korzysta z jasnego tła, białych kart, dużych zaokrągleń i ciepłego koloru identyfikacji VedaSentio. Kolory czerwony, pomarańczowy i zielony są używane przede wszystkim do komunikowania poziomu bezpieczeństwa.
