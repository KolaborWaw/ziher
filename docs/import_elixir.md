# Dokumentacja importu wyciągów bankowych w formacie Elixir

## Spis treści
1. [Wprowadzenie](#wprowadzenie)
2. [Konfiguracja jednostek](#konfiguracja-jednostek)
3. [Format plików Elixir](#format-plików-elixir)
4. [Proces importu](#proces-importu)
5. [Rozwiązywanie problemów](#rozwiązywanie-problemów)
6. [Logi audytowe](#logi-audytowe)

## Wprowadzenie

Aplikacja ZiHeR umożliwia automatyczny import wyciągów bankowych w formacie Elixir. Funkcja ta pozwala na znaczne przyspieszenie wprowadzania danych do księgi bankowej, szczególnie przydatne przy dużej liczbie transakcji.

## Konfiguracja jednostek

Aby korzystać z automatycznego importu, należy:

1. Przejść do edycji jednostki (Menu > Jednostki > [wybrana jednostka] > Edytuj)
2. Wprowadzić numer konta bankowego jednostki
3. Zaznaczyć opcję "Automatyczne ładowanie z banku (Elixir)"
4. Zapisać zmiany

Alternatywnie, administrator może importować numery kont dla wielu jednostek jednocześnie:

1. Przejść do sekcji "Import z banku (Elixir)" w menu głównym
2. Wybrać opcję "Zarządzaj numerami kont"
3. Przesłać plik CSV zawierający kody jednostek i numery kont

### Format pliku CSV z numerami kont
```
kod_jednostki,numer_konta
01ZGD,11114444555566667777888899
02ZGD,99998888777766665555444411
```

## Format plików Elixir

Pliki Elixir to pliki tekstowe zawierające informacje o transakcjach bankowych. Aby system mógł poprawnie przetworzyć pliki, należy przestrzegać następujących zasad:

1. Nazwa pliku powinna zawierać numer konta bankowego jednostki, np. `wyciag_11114444555566667777888899_20240315.csv`
2. Plik powinien zawierać transakcje w formacie CSV

### Struktura pliku CSV
Każdy wiersz pliku powinien zawierać przynajmniej następujące informacje:
- Data transakcji
- Kwota (z uwzględnieniem znaku)
- Tytuł przelewu
- Nadawca/odbiorca
- Numer referencyjny transakcji

### Przykładowy wiersz pliku CSV
```
2024-03-15,123.45,"Składki członkowskie","Jan Kowalski","11112222333344445555666677",REF123456789
```

## Proces importu

1. Przejść do sekcji "Import z banku (Elixir)" w menu głównym
2. Wybrać opcję "Importuj dane Elixir"
3. Przesłać plik Elixir (można wybrać kilka plików jednocześnie)
4. System automatycznie:
   - Rozpozna numer konta na podstawie nazwy pliku
   - Znajdzie odpowiednią jednostkę
   - Zaimportuje transakcje do książki bankowej

### Ważne informacje
- Import jest możliwy tylko dla jednostek z włączoną opcją auto_bank_import
- Jeśli książka bankowa na dany rok nie istnieje, zostanie utworzona automatycznie
- Import jest możliwy tylko do otwartej książki bankowej
- W przypadku problemów z kodowaniem pliku, system próbuje różne kodowania (Windows-1250, ISO-8859-2, CP852, UTF-8)

## Rozwiązywanie problemów

### Typowe problemy i rozwiązania

1. **Problem:** System nie rozpoznaje numeru konta
   **Rozwiązanie:** Upewnij się, że nazwa pliku zawiera pełny numer konta bez spacji i innych znaków

2. **Problem:** Import kończy się błędem kodowania
   **Rozwiązanie:** Zapisz plik w jednym z obsługiwanych kodowań (UTF-8 zalecany)

3. **Problem:** Komunikat "Książka bankowa jest zamknięta"
   **Rozwiązanie:** Otwórz książkę bankową dla danego roku

4. **Problem:** Komunikat "Brak kategorii przychodów lub wydatków"
   **Rozwiązanie:** Utwórz kategorie dla bieżącego roku

## Logi audytowe

System automatycznie zapisuje logi wszystkich importów Elixir. Logi zawierają informacje o:
- Dacie i czasie importu
- Użytkowniku wykonującym import
- Nazwie przesłanego pliku
- Liczbie zaimportowanych transakcji
- Ewentualnych błędach

Administratorzy mogą przeglądać logi w sekcji "Audyt" dostępnej z menu głównego. 