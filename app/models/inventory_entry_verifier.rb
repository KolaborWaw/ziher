class InventoryEntryVerifier

  @errors
  @unit

  def initialize(unit)
    @errors = Hash.new {|h,k| h[k]=""}
    @unit = unit
  end

  def verify(years)
    result = true

    years.each do |year|
      if not verify_sums(year)
        result = false
      end
    end
    return result
  end

  def errors
    return @errors
  end

  private

  def get_inventory_sums(year)
    # Cache key dla zminimalizowania powtórnych obliczeń
    @inventory_sums_cache ||= {}
    cache_key = "inventory_sums_#{@unit.id}_#{year}"
    return @inventory_sums_cache[cache_key] if @inventory_sums_cache[cache_key]
    
    # Globalny cache między żądaniami
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      inventory_sums = Hash.new
      
      # Oryginalna implementacja
      inventory_journal = Array.new
      InventoryEntry.includes(:inventory_source).where(:unit => @unit, :is_expense => false).each do |entry|
        if entry.date.year == year
          inventory_journal << entry
        end
      end

      entries_by_type = Hash.new {|h,k| h[k]=[]}
      inventory_journal.each do |entry|
        entries_by_type[entry.inventory_source] << entry
      end

      entries_by_type.each do |type, entries|
        inventory_sum = entries.sum(&:total_value)
        inventory_sums[type.id] = inventory_sum
      end
      
      # Zapisanie wyniku w pamięci podręcznej instancji
      @inventory_sums_cache[cache_key] = inventory_sums
      inventory_sums
    end
  end

  def get_finance_sums(year)
    finance_sums = Hash.new

    JournalType.all.each do |type|
      finance_sums[type.id] = get_sum(@unit, year, type)
    end

    return finance_sums
  end

  def verify_sums(year)
    result = true

    inventory = get_inventory_sums(year)
    finance = get_finance_sums(year)

    JournalType.all.each do |type|
      inventory_type = type.id

      finance_sum = finance[inventory_type].to_f
      inventory_sum = inventory[inventory_type].to_f

      if finance_sum != inventory_sum
        finance_tag = type.name
        inventory_tag = InventorySource.find(type.id).name

        @errors[finance_tag + year.to_s] << "Proszę o poprawienie książki inwentarzowej dla roku #{year}<br/>" +
            "Kwota wydatków na wyposażenie dla #{finance_tag} <b>(#{finance_sum.to_s})</b> " +
            "jest inna niż suma wartości przychodów książki inwentarzowej dla źródła #{inventory_tag} <b>(#{inventory_sum.to_s})</b>"

        result = false
      end
    end

    return result
  end

  def get_sum(unit, year, type)
    category = Category.find_by(:year => year, :name => 'Wyposażenie')
    return 0 if category.nil?
    
    journal = Journal.includes(entries: :items).find_by_unit_and_year_and_type(unit, year, type)
    return journal.nil? ? 0 : journal.get_sum_for_category(category)
  end

end
