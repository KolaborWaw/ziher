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
      csv_data.each_line do |line|
        line_number += 1
        next if line.blank?
        
        # Parsuj linię CSV z uwzględnieniem wartości w cudzysłowach
        columns = CSV.parse_line(line, col_sep: ',')
        
        # Upewnij się, że mamy wystarczającą liczbę kolumn
        if columns.nil? || columns.length < 2
          next
        end
        
        # Upewnij się, że wszystkie wartości są stringami i usuń ewentualne wiodące/końcowe spacje
        columns.map! { |col| col.to_s.strip }
        
        unit_code = columns[0]
        bank_account = columns[1]
        
        unit = Unit.find_by(code: unit_code)
        if unit
          unit.bank_account = bank_account
          unit.save
        end
      end
      
      redirect_to bank_accounts_path, notice: 'Numery kont zostały zaktualizowane'
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

    params[:elixir_files].each do |file|
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
        import_result = import_elixir_data(elixir_data, unit)
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
  
  def import_elixir_data(elixir_data, unit)
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
          error_messages << "Linia #{line_number}: Nieprawidłowa liczba kolumn (#{columns&.length || 0})"
          next
        end
        
        # Upewnij się, że wszystkie wartości są stringami i usuń ewentualne wiodące/końcowe spacje
        columns.map! { |col| col.to_s.strip }
        
        # Extract data from Elixir format
        transaction_type = columns[0].strip
        date_str = columns[1].strip
        
        # Parsuj kwotę - obsłuż różne formaty
        amount_in_cents = 0
        if !columns[2].blank?
          amount_string = columns[2].strip
          # Jeśli są dziesiątki groszy, traktuj jako grosze, w przeciwnym razie jako pełne grosze
          if amount_string.include?('.') || amount_string.include?(',')
            amount_in_cents = (amount_string.gsub(',', '.').to_f * 100).to_i
          else
            amount_in_cents = amount_string.to_i
          end
        end
        
        # Pobierz opis - głównie z kolumny 12, ewentualnie dołącz 13 jeśli nie jest pusta
        description = columns[11].to_s.strip
        if !columns[12].blank?
          description += " " + columns[12].strip
        end
        
        # Pobierz ID transakcji
        transaction_id = columns[13].to_s.strip
        
        # Jeśli ID transakcji jest puste, wygeneruj unikalne
        if transaction_id.blank?
          transaction_id = "ELIXIR-#{date_str}-#{SecureRandom.hex(4)}"
        end
        
        # Determine if it's income or expense
        is_expense = transaction_type == '222'
        amount = amount_in_cents.to_f / 100.0
        
        # Jeśli kwota wynosi 0, zignoruj wiersz
        if amount <= 0
          next
        end
        
        # Parse date (YYYYMMDD format)
        begin
          if date_str =~ /^(\d{4})(\d{2})(\d{2})$/
            date = Date.new($1.to_i, $2.to_i, $3.to_i)
          else
            error_count += 1
            error_messages << "Linia #{line_number}: Nieprawidłowy format daty: #{date_str}"
            next
          end
        rescue ArgumentError => e
          error_count += 1
          error_messages << "Linia #{line_number}: Nieprawidłowa data: #{date_str} (#{e.message})"
          next
        end
        
        # Skip entries not from current year
        if date.year != current_year
          next
        end
        
        # Zabezpiecz przed pustym opisem
        if description.blank?
          description = "Import Elixir z dnia #{date.strftime('%Y-%m-%d')}"
        end
        
        # Create entry
        entry = bank_journal.entries.build(
          date: date,
          document_number: transaction_id,
          name: description,
          is_expense: is_expense
        )
        
        # Add item with appropriate category
        category = is_expense ? expense_category : income_category
        item = entry.items.build(
          amount: amount,
          category_id: category.id
        )
        
        if entry.save
          success_count += 1
        else
          error_count += 1
          error_messages << "Linia #{line_number}: Błąd zapisywania transakcji: #{entry.errors.full_messages.join(', ')}"
        end
        
      rescue => e
        error_count += 1
        error_messages << "Linia #{line_number}: Błąd przetwarzania linii: #{e.message}"
      end
    end
    
    return { success_count: success_count, error_count: error_count, error_messages: error_messages }
  end
end 