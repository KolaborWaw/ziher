# encoding: utf-8
# TODO: wywalic stringi do I18n
class Entry < ApplicationRecord
  include ActiveModel::Validations
  audited

  has_many :items, dependent: :destroy
  belongs_to :journal
  has_one :linked_entry, :class_name => "Entry", :foreign_key => "linked_entry_id"
  
  # Relacje dla podpozycji
  belongs_to :parent_entry, class_name: "Entry", foreign_key: "parent_entry_id", optional: true
  has_many :subentries, class_name: "Entry", foreign_key: "parent_entry_id", dependent: :destroy

  accepts_nested_attributes_for :items
  accepts_nested_attributes_for :linked_entry

  validates :items, :presence => true
  validates :journal, :presence => true
  validates :date, :presence => true
  validates :name, :presence => true
  # document_number no longer required for all entries
  # validates :document_number, :presence => true
  # statement_number is validated in must_have_statement_number_for_bank_journal
  
  validate :must_be_from_journals_year
  validate :must_have_statement_number_for_bank_journal
  validate :must_have_document_number_for_cash_journal
  validate :cannot_have_multiple_items_in_one_category
  validate :cannot_have_item_from_category_not_from_journals_year
  validate :must_be_either_expense_or_income
  validate :linked_entry_sum_must_match
  validate :linked_entry_must_be_opposite

  # if the journal is closed then everything inside should be frozen
  validate :should_not_change_if_journal_is_closed
  before_destroy :should_not_change_if_journal_is_closed

  after_save :recalculate_initial_balance
  after_destroy :recalculate_initial_balance

  # For backwards compatibility with existing records, provide statement_number getter/setter
  # that falls back to document_number if statement_number is nil
  def statement_number
    self[:statement_number] || self[:document_number]
  end

  def statement_number=(value)
    self[:statement_number] = value
  end

  # Data dokumentu - bez automatycznego fallbacku do daty wyciągu
  def document_date
    self[:document_date]
  end

  def must_have_statement_number_for_bank_journal
    if journal && journal.journal_type_id == JournalType::BANK_TYPE_ID
      if statement_number.blank?
        errors[:base] << "Numer wyciągu jest wymagany dla księgi bankowej"
      end
    end
  end

  def must_have_document_number_for_cash_journal
    if journal && journal.journal_type_id != JournalType::BANK_TYPE_ID
      if document_number.blank?
        errors[:base] << "Numer dokumentu jest wymagany dla księgi kasowej"
      end
    end
  end

  def get_amount_for_category(category)
    category_id = category.is_a?(Category) ? category.id : category
    amount = self.items.find { |item| item.category_id == category_id }&.amount
    amount || 0.0
  end

  def get_amount_one_percent_for_category(category)
    category_id = category.is_a?(Category) ? category.id : category
    amount_one_percent = self.items.find { |item| item.category_id == category_id }&.amount_one_percent
    amount_one_percent || 0.0
  end

  def get_grants_for_category(category)
    items.map(&:grants).flatten.uniq
  end

  def get_amount_for_category_and_grant(category, grant)
    category_id = category.is_a?(Category) ? category.id : category
    grant_id = grant.is_a?(Grant) ? grant.id : grant
    items.map{ |i| i.item_grants }.flatten.select{ |ig| ig.grant_id == grant_id && ig.item.category_id == category_id }.sum(&:amount)
  end

  def get_sum_for_grant(grant)
    grant_id = grant.is_a?(Grant) ? grant.id : grant
    items.map{ |i| i.item_grants }.flatten.select{ |ig| ig.grant_id == grant_id }.sum(&:amount)
  end

  def has_category(category)
    category_id = category.is_a?(Category) ? category.id : category
    items.find { |item| item.category_id == category_id }.present?
  end

  def cannot_have_multiple_items_in_one_category
    categories = []
    items.each do |item|
      if item.category != nil
        categories << item.category.id
      end
    end

    if categories.length != categories.uniq.length
      errors[:items] << 'Wpis nie moze miec kilku sum z tej samej kategorii'
    end
  end

  def one_percent_category_item_should_have_same_amount_values
    items.each do |item|
      if item.category.is_one_percent
        if item.amount != item.amount_one_percent
          errors[:items] << "Niepoprawny wpis dla kategorii 1% (amount=#{item.amount} != amount_one_percent=#{item.amount_one_percent})"
          throw :abort
        end
      end
    end
  end

  def must_be_from_journals_year
    if journal && self.date
      if self.date.year!= journal.year
        errors[:base] << "Wpis nie moze byc z innego roku: journal.year=#{journal.year} != entry.year=#{self.date.year}"
        throw :abort
      end
    end
  end

  def cannot_have_item_from_category_not_from_journals_year
    if journal
      items.each do |item|
        if item.nil? || item.category.nil? || item.category.year.nil?
          errors[:base] << "Wpis musi miec kategorie z danego roku"
          throw :abort
        end

        if item.category.year != journal.year
          errors[:base] << "Wpis nie moze miec sumy dla kategorii z innego roku niz ksiazka: journal.year=#{journal.year} != category.year=#{item.category.year}"
          throw :abort
        end
      end
    end
  end

  def should_not_change_if_journal_is_closed
    if journal
      unless journal.is_not_blocked(self.date)
        errors[:journal] << "Aby zmieniać wpisy książka musi być otwarta"
        throw :abort
      end
    end
  end

  def must_be_either_expense_or_income
    # Podczas zmiany typu wpisu, sprawdzamy tylko kategorie, które mają niezerowe wartości,
    # aby umożliwić zmianę typu wpisu
    non_zero_items = items.select { |item| item.amount && item.amount > 0 }
    
    # Jeśli są jakieś niezerowe elementy, muszą mieć kategorie zgodne z typem wpisu
    different_type_items = non_zero_items.select { |item| item.category.is_expense != self.is_expense }
    
    if different_type_items.any?
      # Jeśli to jest zmiana typu wpisu, ignorujemy ten błąd - walidacja będzie przeprowadzona ponownie po zapisaniu
      # z poprawnymi kategoriami
      unless is_changing_type?
        item_categories = different_type_items.map { |item| item.category.name }.join(", ")
        errors[:base] << "Wszystkie kategorie w wpisie muszą być tego samego typu (#{self.is_expense ? 'wydatek' : 'wpływ'}). Nieprawidłowe kategorie: #{item_categories}"
      end
    end
  end

  def linked_entry_sum_must_match
    if linked_entry != nil
      if self.sum != linked_entry.sum
        errors[:linked_entry] << "Połączony wpis musi mieć taką samą kwotę"
      end
    end
  end

  def linked_entry_must_be_opposite
    if linked_entry != nil
      if self.is_expense == linked_entry.is_expense
        errors[:linked_entry] << "Połączony wpis musi być odwrotnego typu"
      end
    end
  end

  def sum
    @sum ||= items.sum { |item| item.amount ? item.amount : 0 }
  end

  def sum_one_percent
    return 0 if is_expense

    @sum_one_percent ||= items.select { |item| item.category.is_one_percent }.sum { |item| item.amount_one_percent ? item.amount_one_percent : 0 }
  end

  # recalculates initial balance for next year's journal
  def recalculate_initial_balance
    self.journal.recalculate_next_initial_balances
  end

  def verify_entry
    one_percent_category_item_should_have_same_amount_values
  end

  def link_to_edit
    "<a href='#{ENV['RAILS_RELATIVE_URL_ROOT']}/entries/#{self.to_param}/edit'>#{self.date.to_s} - #{self.journal.unit.name}</a>"
  end

  def balance
    return @balance if @balance

    initial_balance = journal.initial_balance
    entries = journal.entries.select { |e| e.date < date || (e.date == date && e.id <= id) }.sort_by(&:date)
    expense_sum = entries.select(&:is_expense).sum { |e| e.sum.to_d }
    income_sum = entries.select { |e| !e.is_expense }.sum { |e| e.sum.to_d }

    @balance = initial_balance + income_sum - expense_sum
  end

  # Pomocnicza metoda określająca czy wpis jest do zmiany
  def is_changing_type?
    return false unless persisted?  # Tylko dla istniejących wpisów
    
    # Sprawdź, czy is_expense się zmieniło
    is_expense_changed = changes.key?('is_expense') && changes['is_expense'][0] != changes['is_expense'][1]
    
    is_expense_changed
  end

  # Metody dla podpozycji
  
  # Czy wpis może mieć podpozycje (tylko główne wpisy w księdze bankowej mogą mieć podpozycje)
  def can_have_subentries?
    result = !is_subentry && journal && journal.journal_type_id == JournalType::BANK_TYPE_ID
    Rails.logger.info "** PODPOZYCJE: can_have_subentries? = #{result} (is_subentry=#{is_subentry}, journal=#{journal&.id}, type=#{journal&.journal_type_id}, bank_type=#{JournalType::BANK_TYPE_ID})"
    result
  end
  
  # Pobieranie oznaczenia pozycji (np. "2a", "2b")
  def position_label(position)
    return position.to_s unless can_have_subentries? || is_subentry
    
    if is_subentry
      Rails.logger.info "** PODPOZYCJE: Generuję etykietę dla podpozycji id=#{id}, parent_id=#{parent_entry_id}, pozycja=#{position}#{subentry_position}"
      "#{position}#{subentry_position}"
    else
      # Główne wpisy z podpozycjami mają oznaczenie "2a"
      Rails.logger.info "** PODPOZYCJE: Generuję etykietę dla głównego wpisu id=#{id}, pozycja=#{position}a"
      "#{position}a"
    end
  end
  
  # Tworzenie lub aktualizacja podpozycji
  def update_subentries(new_count)
    Rails.logger.info "** PODPOZYCJE: Wywołano update_subentries z liczbą #{new_count}"
    
    unless can_have_subentries?
      Rails.logger.info "** PODPOZYCJE: Nie można utworzyć podpozycji. is_subentry=#{is_subentry}, journal_present=#{journal.present?}, journal_type=#{journal&.journal_type_id}, bank_type=#{JournalType::BANK_TYPE_ID}"
      return
    end
    
    current_count = subentries.count
    Rails.logger.info "** PODPOZYCJE: Aktualna liczba podpozycji: #{current_count}"
    
    # Nie rób nic, jeśli liczba podpozycji się nie zmieniła
    if new_count == current_count
      Rails.logger.info "** PODPOZYCJE: Liczba nie zmieniła się, pomijam"
      return
    end
    
    # Aktualizacja liczby podpozycji w głównym wpisie
    Rails.logger.info "** PODPOZYCJE: Aktualizuję liczbę podpozycji na #{new_count + 1}"
    update_column(:subentries_count, new_count + 1) # +1 ponieważ główny wpis liczy się jako pierwsza podpozycja ("a")
    
    if new_count > current_count
      # Dodawanie nowych podpozycji
      Rails.logger.info "** PODPOZYCJE: Dodaję #{new_count - current_count} nowych podpozycji"
      ('b'.ord + current_count..'b'.ord + new_count - 1).each_with_index do |char_code, index|
        position = char_code.chr
        Rails.logger.info "** PODPOZYCJE: Tworzę podpozycję #{position}"
        create_subentry(position, index + current_count + 1)
      end
    elsif new_count < current_count
      # Usuwanie nadmiarowych podpozycji (od końca)
      Rails.logger.info "** PODPOZYCJE: Usuwam #{current_count - new_count} nadmiarowych podpozycji"
      subentries_to_remove = subentries.order(subentry_position: :desc).limit(current_count - new_count)
      subentries_to_remove.destroy_all
    end
    
    Rails.logger.info "** PODPOZYCJE: Zakończono aktualizację podpozycji"
  end
  
  # Tworzenie pojedynczej podpozycji
  def create_subentry(position, order_index)
    Rails.logger.info "** PODPOZYCJE: Rozpoczynam tworzenie podpozycji #{position}"
    
    # Kopiowanie wartości z głównego wpisu
    subentry = self.dup
    
    # Ustawienie pól dotyczących podpozycji
    subentry.is_subentry = true
    subentry.parent_entry_id = self.id # Upewniamy się, że parent_entry_id jest poprawnie ustawiony
    subentry.subentry_position = position
    subentry.subentries_count = 1  # Podpozycje zawsze mają wartość 1
    
    # Zapisujemy informację w logach, aby pomóc w debugowaniu
    Rails.logger.info "** PODPOZYCJE: Tworzę podpozycję dla głównego wpisu id=#{self.id}, pozycja=#{position}"
    
    # Ustawienie odpowiednich wartości domyślnych dla podpozycji
    subentry.name = "Nowa podpozycja do uzupełnienia"
    subentry.document_date = nil   # Pusta data dokumentu
    subentry.document_number = ""  # Pusty numer dokumentu
    
    # WAŻNE: Musimy skopiować items PRZED zapisaniem podpozycji,
    # ponieważ walidacja wymaga obecności items
    Rails.logger.info "** PODPOZYCJE: Tworzę items dla podpozycji - kwota 0,01 tylko dla pierwszej kategorii"
    
    # Flaga do śledzenia czy już przypisaliśmy kwotę 0,01 do jakiejś kategorii
    first_category_found = false
    
    # Tworzymy items z kwotą 0,01 tylko dla pierwszej kategorii, reszta 0,00
    self.items.each do |item|
      # Określ kwotę na podstawie tego, czy to pierwsza kategoria
      amount_value = 0.00
      amount_one_percent_value = 0.00
      
      # Jeśli to pierwsza kategoria, przypisujemy kwotę 0,01
      if !first_category_found
        amount_value = 0.01
        # Dla kategorii 1% ustawiamy również amount_one_percent na 0,01
        amount_one_percent_value = item.category.is_one_percent ? 0.01 : 0.00
        first_category_found = true
      end
        
      # Użyj build zamiast create, aby utworzyć obiekt ale nie zapisywać go jeszcze
      new_item = subentry.items.build(
        amount: amount_value,
        amount_one_percent: amount_one_percent_value,
        category_id: item.category_id
      )
    end
    
    # Zapisanie podpozycji razem z wszystkimi powiązanymi items
    if subentry.save
      Rails.logger.info "** PODPOZYCJE: Utworzono podpozycję #{position} (ID: #{subentry.id}) z #{subentry.items.count} items, kwota 0,01 tylko w pierwszej kategorii"
      return subentry
    else
      Rails.logger.error "** PODPOZYCJE: Błąd podczas tworzenia podpozycji #{position}: #{subentry.errors.full_messages.join(', ')}"
      return nil
    end
  end
end
