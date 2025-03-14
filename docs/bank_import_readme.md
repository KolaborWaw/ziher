# Automatyczne ładowanie danych bankowych (Elixir) w ZiHeR

## Informacje ogólne

Funkcjonalność automatycznego ładowania danych bankowych umożliwia superadministratorom systemu ZiHeR importowanie transakcji bankowych bezpośrednio z plików w formacie Elixir do książek bankowych jednostek. Funkcjonalność ta jest dostępna wyłącznie dla użytkowników z uprawnieniami superadministratora.

## Dla superadministratorów

### Konfiguracja jednostek

1. Przejdź do sekcji "Administracja" -> "Jednostki"
2. Edytuj wybraną jednostkę
3. Wprowadź numer konta bankowego jednostki
4. Zaznacz opcję "Automatyczne ładowanie z banku (Elixir)" jeśli chcesz, aby dla tej jednostki można było automatycznie importować dane
5. Zapisz zmiany

### Zarządzanie numerami kont bankowych

1. Przejdź do sekcji "Administracja" -> "Import z banku (Elixir)"
2. Kliknij "Zarządzaj numerami kont"
3. Możesz:
   - Wczytać plik CSV z kodami jednostek i numerami kont (format: `kod_jednostki,numer_konta`)
   - Przeglądać listę jednostek i ich numerów kont

### Importowanie danych Elixir

1. Przejdź do sekcji "Administracja" -> "Import z banku (Elixir)"
2. Kliknij "Importuj dane Elixir"
3. Wybierz pliki Elixir do importu (możesz wybrać wiele plików jednocześnie)
4. Kliknij "Importuj dane"

Ważne informacje:
- Nazwa pliku musi zawierać numer konta bankowego jednostki
- Jednostka musi mieć włączoną opcję automatycznego importu danych bankowych
- Import jest możliwy tylko do otwartych ksiąg bankowych za bieżący rok
- Importowane są tylko transakcje z bieżącego roku

### Usuwanie wpisów z książki bankowej

1. Przejdź do sekcji "Administracja" -> "Import z banku (Elixir)"
2. Znajdź jednostkę na liście i kliknij "Usuń wpisy z [rok]"
3. Potwierdź operację, wpisując "USUŃ WSZYSTKIE WPISY" w polu potwierdzenia
4. Kliknij "Potwierdzam usunięcie wszystkich wpisów"

## Dla użytkowników

Użytkownicy nie mają bezpośredniego dostępu do funkcji importu danych bankowych. Jednak mogą:

1. Przeglądać wpisy w książce bankowej, które zostały zaimportowane automatycznie
2. Edytować zaimportowane wpisy (jeśli mają odpowiednie uprawnienia)
3. Widzieć, że jednostka ma włączoną opcję automatycznego importu danych bankowych (tylko informacyjnie)

## Struktura pliku Elixir

Pliki Elixir powinny mieć następującą strukturę:
- Format: kolumny oddzielone przecinkami, wartości tekstowe w cudzysłowach
- Kolumna 1: Typ transakcji (111 = wpływ, 222 = wydatek)
- Kolumna 2: Data w formacie YYYYMMDD
- Kolumna 3: Kwota w groszach
- Kolumny 12-13: Tytuł/opis transakcji
- Kolumna 14: Unikalny identyfikator transakcji (używany jako numer dokumentu)

## Bezpieczeństwo

System implementuje następujące zabezpieczenia:
1. Dostęp do funkcji importu mają wyłącznie superadministratorzy
2. Pliki są walidowane pod kątem formatu i zawartości
3. Import jest możliwy tylko do otwartych ksiąg bankowych
4. Usuwanie wpisów wymaga dodatkowego potwierdzenia
5. Wszystkie operacje są zapisywane w dzienniku zmian

## Scenariusze testowe (UAT)

### Scenariusz 1: Konfiguracja jednostki
1. Zaloguj się jako superadmin
2. Przejdź do edycji jednostki
3. Wprowadź numer konta i zaznacz opcję auto-importu
4. Sprawdź, czy zmiany zostały zapisane

### Scenariusz 2: Import pliku CSV z numerami kont
1. Przygotuj plik CSV z kodami jednostek i numerami kont
2. Zaloguj się jako superadmin
3. Przejdź do zarządzania numerami kont
4. Wczytaj plik CSV
5. Sprawdź, czy numery kont zostały zaktualizowane

### Scenariusz 3: Import danych Elixir
1. Przygotuj plik Elixir z transakcjami
2. Zaloguj się jako superadmin
3. Przejdź do importu danych Elixir
4. Wczytaj plik Elixir
5. Sprawdź, czy transakcje zostały zaimportowane do odpowiedniej książki bankowej

### Scenariusz 4: Usuwanie wpisów z książki bankowej
1. Zaloguj się jako superadmin
2. Przejdź do zarządzania kontami bankowymi
3. Kliknij "Usuń wpisy" dla wybranej jednostki
4. Potwierdź operację
5. Sprawdź, czy wpisy zostały usunięte

### Scenariusz 5: Próba importu do zamkniętej książki
1. Zamknij książkę bankową dla wybranej jednostki
2. Zaloguj się jako superadmin
3. Spróbuj zaimportować dane Elixir
4. Sprawdź, czy system wyświetla odpowiedni komunikat o błędzie 