# Zmiana identyfikatora aplikacji Android

## Cel

Przed konfiguracją Firebase zmieniono domyślny identyfikator utworzony przez
Fluttera na docelowy identyfikator projektu VedaSentio.

Stary identyfikator:

`com.example.vedasentio_mobile`

Nowy identyfikator:

`com.kamilsoftware.vedasentio`

## Zakres zmian

Zmiana obejmuje:

- `namespace` projektu Android,
- `applicationId`,
- deklarację pakietu klasy `MainActivity`,
- strukturę katalogów odpowiadającą nazwie pakietu.

## Dlaczego wykonano zmianę przed Firebase

Identyfikator aplikacji Android jest używany przez zewnętrzne usługi do
rozpoznawania konkretnej aplikacji. Firebase również rejestruje aplikację
Android przy użyciu tego identyfikatora.

Dlatego docelową nazwę ustalono przed utworzeniem konfiguracji Firebase.
Pozwala to uniknąć późniejszego przepinania projektu do nowego identyfikatora.

## Wybrana nazwa

`com.kamilsoftware.vedasentio`

Nazwa składa się z:

- domeny organizacyjnej zapisanej w odwrotnej kolejności,
- nazwy marki,
- nazwy aplikacji.

Na tym etapie nie dodano jeszcze konfiguracji Firebase.
