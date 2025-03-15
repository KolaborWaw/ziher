require 'securerandom'
require 'csv'

class BankAccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_superadmin

  def index
    @units = Unit.all.order(:code)
  end

  def upload_associations
    @unit_accounts = {}
  end

  def process_associations
    if params[:csv_file].blank?
      redirect_to upload_associations_bank_accounts_path, alert: 'Nie wybrano pliku CSV'
      return
    end

    begin
      csv_data = params[:csv_file].read.force_encoding('UTF-8')
      csv_data.gsub!(/\r\n?/, "\n") # Normalize line endings
      
      line_number = 0
      success_count = 0
      error_count = 0
      errors = []
      
      csv_data.each_line do |line|
        line_number += 1
        next if line.blank?
        
        begin
          # Parsuj linię CSV z uwzględnieniem wartości w cudzysłowach
          columns = CSV.parse_line(line, col_sep: ',')
          
          # Upewnij się, że mamy wystarczającą liczbę kolumn
          if columns.nil? || columns.length < 2
            error_count += 1
            errors << "Linia #{line_number}: nieprawidłowa liczba kolumn"
            next
          end
          
          # Upewnij się, że wszystkie wartości są stringami i usuń ewentualne wiodące/końcowe spacje
          columns.map! { |col| col.to_s.strip }
          
          unit_code = columns[0]
          bank_account = columns[1]
          
          unit = Unit.find_by(code: unit_code)
          if unit
            unit.bank_account = bank_account
            # Automatycznie włącz auto_bank_import jeśli jest numer konta
            unit.auto_bank_import = true if bank_account.present?
            if unit.save
              success_count += 1
            else
              error_count += 1
              errors << "Linia #{line_number}: nie udało się zapisać jednostki #{unit_code} - #{unit.errors.full_messages.join(', ')}"
            end
          else
            error_count += 1
            errors << "Linia #{line_number}: nie znaleziono jednostki o kodzie #{unit_code}"
          end
        rescue CSV::MalformedCSVError => e
          error_count += 1
          errors << "Linia #{line_number}: błąd parsowania CSV - #{e.message}"
        rescue => e
          error_count += 1
          errors << "Linia #{line_number}: nieznany błąd - #{e.message}"
        end
      end
      
      if error_count > 0
        redirect_to bank_accounts_path, alert: "Numery kont zostały zaktualizowane z błędami (#{success_count} sukces, #{error_count} błędy)"
      else
        redirect_to bank_accounts_path, notice: "Numery kont zostały zaktualizowane (#{success_count} jednostek)"
      end
    rescue => e
      redirect_to upload_associations_bank_accounts_path, alert: "Błąd przetwarzania pliku: #{e.message}"
    end
  end

  def upload_elixir
    # For elixir file upload page
  end

  def process_elixir
    if params[:elixir_files].blank?
      redirect_to upload_elixir_bank_accounts_path, alert: 'Nie wybrano plików Elixir'
      return
    end

    success_count = 0
    error_count = 0
    error_messages = []

    # Sortuj pliki po nazwie (ELIXIR_NUMERKONTA_YYYYMMDD)
    sorted_files = params[:elixir_files].sort_by { |file| file.original_filename }

    sorted_files.each do |file|
      begin
        # Próba różnych kodowań
        raw_data = file.read
        elixir_data = nil
        
        # Wypróbuj różne kodowania
        ['Windows-1250', 'ISO-8859-2', 'CP852', 'UTF-8'].each do |encoding|
          begin
            elixir_data = raw_data.dup.force_encoding(encoding).encode('UTF-8')
            break
          rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
            next
          end
        end
        
        if elixir_data.nil?
          error_count += 1
          error_messages << "Nie można ustalić kodowania pliku: #{file.original_filename}"
          next
        end
        
        # Normalizacja końców linii
        elixir_data.gsub!(/\r\n?/, "\n")
        
        # Extract account number from filename (assuming it's part of the filename)
        filename = file.original_filename
        account_number = extract_account_number(filename)
        
        if account_number.blank?
          error_count += 1
          error_messages << "Nie można określić numeru konta na podstawie nazwy pliku: #{filename}"
          next
        end
        
        # Find unit with this account number
        unit = Unit.find_by(bank_account: account_number)
        
        if unit.nil?
          error_count += 1
          error_messages << "Nie znaleziono jednostki z numerem konta: #{account_number} (plik: #{filename})"
          next
        end
        
        if !unit.auto_bank_import
          error_count += 1
          error_messages << "Jednostka #{unit.name} nie ma włączonego automatycznego importu (plik: #{filename})"
          next
        end
        
        # Process Elixir file
        import_result = import_elixir_data(elixir_data, unit, nil)
        success_count += import_result[:success_count]
        error_count += import_result[:error_count]
        error_messages.concat(import_result[:error_messages])
        
      rescue => e
        error_count += 1
        error_messages << "Błąd przetwarzania pliku #{file.original_filename}: #{e.message}"
      end
    end

    if error_count > 0
      flash[:alert] = "Import zakończony z błędami (#{success_count} sukces, #{error_count} błędy): #{error_messages.join('; ')}"
    else
      flash[:notice] = "Import zakończony pomyślnie. Dodano #{success_count} transakcji."
    end
    
    redirect_to upload_elixir_bank_accounts_path
  end

  def clear_journal_entries
    @unit = Unit.find(params[:unit_id])
    @year = params[:year].to_i
    
    # Just show confirmation page
  end

  def perform_clear_journal_entries
    @unit = Unit.find(params[:unit_id])
    @year = params[:year].to_i
    
    bank_journal = @unit.journals.find_by(year: @year, journal_type_id: JournalType::BANK_TYPE_ID)
    
    if bank_journal.nil?
      redirect_to bank_accounts_path, alert: "Nie znaleziono książki bankowej dla jednostki #{@unit.name} za rok #{@year}"
      return
    end
    
    if !bank_journal.is_open
      redirect_to bank_accounts_path, alert: "Książka bankowa dla jednostki #{@unit.name} za rok #{@year} jest zamknięta"
      return
    end
    
    # Delete all entries
    entries_count = bank_journal.entries.count
    
    bank_journal.entries.destroy_all
    
    redirect_to bank_accounts_path, notice: "Usunięto #{entries_count} wpisów z książki bankowej jednostki #{@unit.name} za rok #{@year}"
  end

  def toggle_auto_import
    @unit = Unit.find(params[:unit_id])
    @unit.auto_bank_import = !@unit.auto_bank_import
    
    if @unit.save
      status = @unit.auto_bank_import ? "włączony" : "wyłączony"
      redirect_to bank_accounts_path, notice: "Auto import dla jednostki #{@unit.name} został #{status}"
    else
      redirect_to bank_accounts_path, alert: "Nie udało się zmienić ustawienia auto importu dla jednostki #{@unit.name}"
    end
  end

  private
  
  def require_superadmin
    unless current_user && current_user.is_superadmin
      redirect_to root_path, alert: 'Brak uprawnień'
    end
  end
  
  def extract_account_number(filename)
    # Extract account number from filename - adjust this based on actual filename format
    # This is a simple example that looks for a sequence of digits that might be an account number
    match = filename.match(/\d{10,26}/)
    match ? match[0] : nil
  end
  
  def import_elixir_data(elixir_data, unit, import_log)
    success_count = 0
    error_count = 0
    error_messages = []
    
    # Get or create bank journal for current year
    current_year = Date.today.year
    bank_journal = unit.journals.find_by(year: current_year, journal_type_id: JournalType::BANK_TYPE_ID)
    
    if bank_journal.nil?
      error_count += 1
      error_messages << "Nie znaleziono książki bankowej dla jednostki #{unit.name} za rok #{current_year}"
      return { success_count: success_count, error_count: error_count, error_messages: error_messages }
    end
    
    if !bank_journal.is_open
      error_count += 1
      error_messages << "Książka bankowa dla jednostki #{unit.name} za rok #{current_year} jest zamknięta"
      return { success_count: success_count, error_count: error_count, error_messages: error_messages }
    end
    
    # Get category for bank entries
    income_category = Category.where(year: current_year, is_expense: false).first
    expense_category = Category.where(year: current_year, is_expense: true).first
    
    if income_category.nil? || expense_category.nil?
      error_count += 1
      error_messages << "Brak kategorii przychodów lub wydatków dla roku #{current_year}"
      return { success_count: success_count, error_count: error_count, error_messages: error_messages }
    end
    
    # Zbierz wszystkie wpisy do przetworzenia
    entries_to_import = []
    
    line_number = 0
    elixir_data.each_line do |line|
      line_number += 1
      next if line.blank?
      
      begin
        # Użyj biblioteki CSV do poprawnego parsowania linii, uwzględniając przecinki w cudzysłowach
        columns = CSV.parse_line(line, col_sep: ',')
        
        # Upewnij się, że mamy wystarczającą liczbę kolumn
        if columns.nil? || columns.length < 15
          error_count += 1
          error_messages << "Linia #{line_number}: Niewystarczająca liczba pól (#{columns&.length || 0})"
          next
        end
        
        # Parsuj datę transakcji - kolumna 2
        begin
          transaction_date = Date.parse(columns[1])
        rescue ArgumentError
          error_count += 1
          error_messages << "Linia #{line_number}: Nieprawidłowy format daty (#{columns[1]})"
          next
        end
        
        # Sprawdź czy transakcja jest z bieżącego roku
        if transaction_date.year != current_year
          error_count += 1
          error_messages << "Linia #{line_number}: Transakcja nie jest z bieżącego roku (#{transaction_date.year})"
          next
        end
        
        # Parsuj kwotę - kolumna 3 (w groszach)
        begin
          amount_in_cents = columns[2].to_i
          amount = amount_in_cents / 100.0
          
          # Określ czy to wydatek czy wpływ na podstawie kolumny 1 (111=wpływ, 222=wydatek)
          is_expense = columns[0] == "222"
          if is_expense
            amount = -amount  # Wydatek ma być ujemny
          end
        rescue
          error_count += 1
          error_messages << "Linia #{line_number}: Nieprawidłowy format kwoty (#{columns[2]})"
          next
        end
        
        # Pobierz tytuł przelewu - kolumna 12
        transaction_title = columns[11].to_s.strip
        
        # Pobierz id transakcji - kolumna 14
        transaction_id = columns[13].to_s.strip
        
        # Pobierz lub utwórz numer wyciągu - kolumna 15 lub format MM/YYYY
        statement_number = ""
        if columns.length >= 15 && columns[14].present?
          statement_number = columns[14].to_s.strip
        else
          # Jeśli brak numeru wyciągu, użyj formatu MM/YYYY
          statement_number = "#{transaction_date.month}/#{transaction_date.year}"
        end
        
        # Utwórz wpis - używając dostępnych pól zgodnie z instrukcją
        entry = bank_journal.entries.new(
          date: transaction_date,         # Data transakcji
          document_number: transaction_id, # ID transakcji jako numer dokumentu
          name: transaction_title,        # Tytuł/opis transakcji 
          is_expense: is_expense,         # Czy to wydatek
          statement_number: statement_number   # Numer wyciągu
          # Brak document_date - zgodnie z instrukcją nie uzupełniamy
        )
        
        # Dodaj pozycję do wpisu
        category = is_expense ? expense_category : income_category
        entry.items.build(
          category: category,
          amount: amount.abs  # Zawsze dodatnia kwota w pozycji
        )
        
        # Zapisz wpis
        if entry.save
          success_count += 1
        else
          error_count += 1
          error_messages << "Linia #{line_number}: Nie udało się zapisać wpisu - #{entry.errors.full_messages.join(', ')}"
        end
        
      rescue CSV::MalformedCSVError => e
        error_count += 1
        error_messages << "Linia #{line_number}: Błąd parsowania CSV - #{e.message}"
      rescue => e
        error_count += 1
        error_messages << "Linia #{line_number}: Nieznany błąd - #{e.message}"
      end
    end
    
    return { success_count: success_count, error_count: error_count, error_messages: error_messages }
  end
end 