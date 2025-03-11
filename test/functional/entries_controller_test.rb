require 'test_helper'

class EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:master_1zgm)
    @entry = entries(:expense_one)
    @entry_income = entries(:income_one)
  end

  test "should get new" do
    # get :new, params: {journal_id: @entry.journal_id}
    get new_entry_path, params: {journal_id: @entry.journal_id}
    assert_response :success
  end

  test "should create entry" do
    assert_difference('Entry.count') do

      new_hash = @entry.attributes
      items_hash = Hash.new
      i = 0
      @entry.items.each do |item|
        items_hash[i.to_s] = item.attributes
        items_hash[i.to_s]["id"] = nil
        i += 1
      end
      new_hash["items_attributes"] = items_hash
      new_hash["id"] = nil

      post entries_url, params: {entry: new_hash}
    end

    assert_redirected_to journal_path(@entry.journal)
  end

  test "should show all possible categories when editing existing expense entry" do
    get edit_entry_path(@entry)
    assert_select "input.category", Category.where(:year => @entry.journal.year, :is_expense => @entry.is_expense).count * 2
    #przenoszenie kwot miedzy ksiazkami na razie wstrzymane
    #+ Category.where(:year => @entry.journal.year, :is_expense => !@entry.is_expense).count
    Category.where(:year => @entry.journal.year, :is_expense => @entry.is_expense).each do |category|
      assert_select "input.category_id[value='#{category.id}']", true
    end
  end

  test "should show all possible categories when editing existing income entry" do
    get edit_entry_path(@entry_income)
    assert_select "input.category", Category.where(:year => @entry_income.journal.year, :is_expense => @entry_income.is_expense).count
    Category.where(:year => @entry_income.journal.year, :is_expense => @entry_income.is_expense).each do |category|
      assert_select "input.category_id[value='#{category.id}']", true
    end
  end

  test "should not show categories from different years" do
    get edit_entry_path(@entry)
    Category.where('year <> ?', @entry.journal.year).each do |category|
      assert_select "input.category_id[value='#{category.id}']", false
    end
  end

  test "should not show duplicate categories when editing existing expense entry" do
    get edit_entry_path(@entry)
    put entry_url(@entry), params: {entry: {name: "updated"}}
    get edit_entry_path(@entry)
    assert_select "input.category", Category.where(:year => @entry.journal.year, :is_expense => @entry.is_expense).count * 2
    #przenoszenie kwot miedzy ksiazkami na razie wstrzymane
    #+ Category.where(:year => @entry.journal.year, :is_expense => !@entry.is_expense).count
  end

  test "should not show duplicate categories when editing existing income entry" do
    get edit_entry_path(@entry_income)
    put entry_url(@entry_income), params: {entry: {name: "updated"}}
    get edit_entry_path(@entry_income)
    assert_select "input.category", Category.where(:year => @entry_income.journal.year, :is_expense => @entry_income.is_expense).count
  end

  test "should show entry" do
    get entry_path(@entry)
    assert_response :success
  end

  test "should get edit" do
    get edit_entry_path(@entry)
    assert_response :success
  end

  test "should edit items when editing entry" do
    get edit_entry_path(@entry)
    assert_select "input.category"
  end

  test "should update entry" do
    put entry_url(@entry), params: {entry: {name: "updated"}}
    assert_redirected_to journal_path(assigns(:journal))
  end

  test "should destroy entry" do
    assert_difference('Entry.count', -1) do
      delete entry_path(@entry)
    end

    assert_redirected_to journal_path(@entry.journal)
  end

  test "should show type switch form radio buttons when editing entry" do
    get edit_entry_path(@entry)
    assert_select "input#entry_type_expense[type=radio]", 1
    assert_select "input#entry_type_income[type=radio]", 1
  end

  test "should change categories when changing entry type" do
    # Test dla zmiany wpisu typu wydatek na wpływ
    get edit_entry_path(@entry), params: {type_changed: true}
    assert_response :success
    assert_select "input.category", Category.where(:year => @entry.journal.year, :is_expense => false).count
    
    # Test dla zmiany wpisu typu wpływ na wydatek
    get edit_entry_path(@entry_income), params: {type_changed: true}
    assert_response :success
    assert_select "input.category", Category.where(:year => @entry_income.journal.year, :is_expense => true).count * 2
  end

  test "should update entry with changed type" do
    # Konwersja z wydatku na wpływ
    attributes = @entry.attributes
    attributes["is_expense"] = false
    
    put entry_url(@entry), params: {entry: attributes}
    assert_redirected_to journal_path(assigns(:journal))
    
    # Sprawdź, czy typ został zmieniony
    updated_entry = Entry.find(@entry.id)
    assert_equal false, updated_entry.is_expense
    
    # Konwersja z wpływu na wydatek
    attributes = @entry_income.attributes
    attributes["is_expense"] = true
    
    put entry_url(@entry_income), params: {entry: attributes}
    assert_redirected_to journal_path(assigns(:journal))
    
    # Sprawdź, czy typ został zmieniony
    updated_income_entry = Entry.find(@entry_income.id)
    assert_equal true, updated_income_entry.is_expense
  end

  test "should handle type change in edit form" do
    # Test dla zmiany wpisu typu wydatek na wpływ
    get edit_entry_path(@entry), params: {type_changed: true}
    assert_response :success
    
    # Powinien pokazać kategorie dla wpływów, nie dla wydatków
    assert_select "input.category", Category.where(:year => @entry.journal.year, :is_expense => false).count
    
    # Sprawdź, czy is_expense zostało zmienione w formularzu
    assert_select "input[type=hidden][name='entry[is_expense]'][value=false]", 1
  end
  
  test "should handle type change with validation errors" do
    # Przygotuj dane z błędem walidacji (brak nazwy)
    attributes = @entry.attributes
    attributes["is_expense"] = false
    attributes["name"] = ""
    
    put entry_url(@entry), params: {entry: attributes}
    assert_response :success  # Powinien renderować formularz edycji
    assert_select "div#error_explanation", 1  # Powinien zawierać komunikat o błędzie
    
    # Dane w bazie nie powinny się zmienić
    unchanged_entry = Entry.find(@entry.id)
    assert_equal @entry.is_expense, unchanged_entry.is_expense
    assert_equal @entry.name, unchanged_entry.name
  end

  test "should preserve referer when updating entry" do
    # Ustaw referer na konkretny URL
    referer_url = journal_path(@entry.journal)
    
    attributes = @entry.attributes
    attributes["name"] = "Updated name"
    
    put entry_url(@entry), params: {entry: attributes.merge(referer: referer_url)}
    assert_redirected_to referer_url
  end
  
  test "should preserve referer when creating entry" do
    # Ustaw referer na konkretny URL
    referer_url = journal_path(@entry.journal)
    
    # Przygotuj nowy wpis
    new_hash = @entry.attributes
    items_hash = Hash.new
    i = 0
    @entry.items.each do |item|
      items_hash[i.to_s] = item.attributes
      items_hash[i.to_s]["id"] = nil
      i += 1
    end
    new_hash["items_attributes"] = items_hash
    new_hash["id"] = nil
    new_hash["referer"] = referer_url
    
    post entries_url, params: {entry: new_hash}
    assert_redirected_to referer_url
  end

  test "should render correct type switch interface in edit form" do
    get edit_entry_path(@entry)
    assert_response :success
    
    # Sprawdź, czy formularz zawiera przyciski radio do zmiany typu
    assert_select "input#entry_type_expense[type=radio]", 1
    assert_select "input#entry_type_income[type=radio]", 1
    
    # Sprawdź, czy jest informacja pomocnicza o zmianie typu
    assert_select "div.help-block", 1
  end
  
  test "should not show type switch in new form" do
    get new_entry_path, params: {journal_id: @entry.journal_id}
    assert_response :success
    
    # Sprawdź, czy formularz NIE zawiera przycisków radio do zmiany typu
    assert_select "input#entry_type_expense[type=radio]", 0
    assert_select "input#entry_type_income[type=radio]", 0
    
    # Powinien zawierać ukryte pole z typem wpisu
    assert_select "input[type=hidden][name='entry[is_expense]']", 1
  end
  
  test "should show warning after type change" do
    get edit_entry_path(@entry), params: {type_changed: true}
    assert_response :success
    
    # Sprawdź, czy pojawia się ostrzeżenie po zmianie typu
    assert_select "div.alert-warning", 1
    
    # Sprawdź, czy NIE pokazują się przyciski radio po zmianie typu
    assert_select "input#entry_type_expense[type=radio]", 0
    assert_select "input#entry_type_income[type=radio]", 0
  end
  
  test "should handle linked entries when changing type" do
    # Utwórz wpis z połączonym wpisem
    source_entry = entries(:expense_one)
    linked_entry = entries(:income_one)
    
    source_entry.linked_entry = linked_entry
    source_entry.save!
    
    # Zmień typ wpisu źródłowego
    attributes = source_entry.attributes
    attributes["is_expense"] = false
    
    put entry_url(source_entry), params: {entry: attributes}
    
    # Sprawdź, czy typy są nadal przeciwne
    updated_source = Entry.find(source_entry.id)
    updated_linked = Entry.find(linked_entry.id)
    
    assert_equal false, updated_source.is_expense
    assert_equal true, updated_linked.is_expense
  end

  test 'should not save empty entry' do
    # given
    entries_count_before = Entry.count
    empty_entry = copy_to_new_hash(@entry)
    reset_amounts(empty_entry)

    # when
    post entries_url, params: {entry: empty_entry}

    #then
    entries_count_after = Entry.count
    assert_equal(entries_count_before, entries_count_after)
  end

  test "should delete items associated with entry" do
    items_count = @entry.items.count
    assert_difference('Item.count', items_count * -1) do
      delete entry_path(@entry)
    end
  end

  def copy_to_new_hash(entry)
    new_hash = entry.attributes
    items_hash = Hash.new
    i = 0
    entry.items.each do |item|
      items_hash[i.to_s] = item.attributes
      items_hash[i.to_s]['id'] = nil
      i += 1
    end
    new_hash['items_attributes'] = items_hash
    new_hash['id'] = nil
    new_hash
  end

  def reset_amounts(entry)
    (0 .. entry['items_attributes'].length - 1).each {|i|
      entry['items_attributes'][i.to_s]['amount'] = 0
    }
  end
end
