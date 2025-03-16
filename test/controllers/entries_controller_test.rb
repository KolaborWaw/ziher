require 'test_helper'

class EntriesControllerTest < ActionController::TestCase
  setup do
    @entry = entries(:one)
    @user = users(:admin)
    sign_in @user
  end
  
  # Test dla wpisów ELIXIR - zachowując sumę bezwzględną
  test "should preserve absolute sum when changing type for ELIXIR entries" do
    # Przygotowanie wpisu ELIXIR
    @entry.journal.unit.update(auto_bank_import: true)
    @entry.journal.update(journal_type_id: JournalType::BANK_TYPE_ID)
    @entry.update(document_number: "ELIXIR_123", is_expense: true)
    
    # Dodajmy dwa elementy do wpisu
    item1 = @entry.items.first || @entry.items.build(amount: -50, category: categories(:one))
    item1.update(amount: -50)
    item2 = @entry.items.build(amount: -30, category: categories(:two))
    item2.save!
    
    # Symulujmy zmianę typu wpisu
    session[:entry_type_changed] = true
    session[:original_abs_sum] = 80 # Suma bezwzględna: |-50| + |-30| = 80
    
    # Wykonaj aktualizację wpisu
    put :update, id: @entry.id, entry: { 
      is_expense: false, # Zmiana z wydatku na wpływ
      items_attributes: {
        "0" => { id: item1.id, amount: -50, category_id: item1.category_id },
        "1" => { id: item2.id, amount: -30, category_id: item2.category_id }
      }
    }
    
    # Sprawdź, czy aktualizacja się powiodła
    assert_redirected_to journal_path(@entry.journal)
    
    # Pobierz zaktualizowany wpis
    updated_entry = Entry.find(@entry.id)
    
    # Sprawdź, czy typ się zmienił
    assert_equal false, updated_entry.is_expense
    
    # Sprawdź, czy wartości zostały prawidłowo odwrócone (zmiana znaku)
    updated_items = updated_entry.items.sort_by(&:id)
    assert_equal 50, updated_items[0].amount.to_f
    assert_equal 30, updated_items[1].amount.to_f
    
    # Sprawdź, czy suma bezwzględna pozostała taka sama (80)
    assert_equal 80, updated_items.sum { |i| i.amount.to_f.abs }
  end
  
  # Test dla zwykłych wpisów - przenoszenie całej wartości do pierwszej kategorii
  test "should move entire amount to first category when changing type for non-ELIXIR entries" do
    # Przygotowanie zwykłego wpisu (nie ELIXIR)
    @entry.journal.unit.update(auto_bank_import: false)
    @entry.update(document_number: "ZWYKLY_123", is_expense: true)
    
    # Dodajmy dwa elementy do wpisu
    item1 = @entry.items.first || @entry.items.build(amount: -50, category: categories(:one))
    item1.update(amount: -50)
    item2 = @entry.items.build(amount: -30, category: categories(:two))
    item2.save!
    
    # Symulujmy zmianę typu wpisu
    session[:entry_type_changed] = true
    session[:original_abs_sum] = 80 # Suma bezwzględna: |-50| + |-30| = 80
    
    # Wykonaj aktualizację wpisu
    put :update, id: @entry.id, entry: { 
      is_expense: false, # Zmiana z wydatku na wpływ
      items_attributes: {
        "0" => { id: item1.id, amount: -50, category_id: item1.category_id },
        "1" => { id: item2.id, amount: -30, category_id: item2.category_id }
      }
    }
    
    # Sprawdź, czy aktualizacja się powiodła
    assert_redirected_to journal_path(@entry.journal)
    
    # Pobierz zaktualizowany wpis
    updated_entry = Entry.find(@entry.id)
    
    # Sprawdź, czy typ się zmienił
    assert_equal false, updated_entry.is_expense
    
    # Sprawdź, czy całkowita wartość została przeniesiona do pierwszej kategorii
    updated_items = updated_entry.items.sort_by(&:id)
    assert_equal 80, updated_items[0].amount.to_f  # Cała suma w pierwszej kategorii
    assert_equal 0, updated_items[1].amount.to_f   # Zero w drugiej kategorii
    
    # Sprawdź, czy suma bezwzględna pozostała taka sama (80)
    assert_equal 80, updated_items.sum { |i| i.amount.to_f.abs }
  end
end 