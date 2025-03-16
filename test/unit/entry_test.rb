require 'test_helper'

class EntryTest < ActiveSupport::TestCase
  fixtures :categories
  fixtures :journals

  test "should not save entry without items" do
    entry = entries(:expense_one)
    entry.items = []
    assert_raise(ActiveRecord::RecordInvalid){
      entry.save!
    }
  end

  test "should not save entry without journal" do
    entry = entries(:expense_one)
    entry.journal = nil
    assert_raise(ActiveRecord::RecordInvalid){
      entry.save!
    }
  end

  test "should not save entry with multiple items of one category" do
    entry = entries(:expense_one)
    category = categories(:one)

    item1 = Item.new(:amount => 0, :category => category)
    item2 = Item.new(:amount => 0, :category => category)
    entry.items << item1 << item2

    assert_raise(ActiveRecord::RecordInvalid){
      entry.save!
    }
  end

  test "should not add item with duplicate category" do
    entry = entries(:expense_one)
    category = categories(:one)

    item1 = Item.new(:amount => 0, :category => category)
    item2 = Item.new(:amount => 0, :category => category)
    items = []
    items << item1 << item2

    assert_raise(ActiveRecord::RecordInvalid){
      entry.update_attributes!(:items => items)
    }
  end

  test "should not save entry from different year" do
    #given
    entry = entries(:expense_one)

    #when - the date is from previous year (from 12 months before)
    entry.date <<= 12

    #then
    assert_raise(ActiveRecord::RecordInvalid){
      entry.save!
    }
  end

  test "should not save entry with items of categories from different year" do
    entry = entries(:expense_one)
    item1 = Item.new(:category => categories(:one))
    entry.items << item1

    assert_raise(ActiveRecord::RecordInvalid){
      assert entry.save!
    }
  end

  test "should save entry with items of different categories" do
    entry = entries(:expense_one)
    item1 = Item.new(:amount => 0, :category => categories(:seven))
    item2 = Item.new(:amount => 0, :category => categories(:eight))
    entry.items << item1 << item2

    assert entry.save!
  end

  test "should add items to existing entry" do
    entry = entries(:expense_one)

    item2 = Item.new(:amount => 0, :category => categories(:seven))
    entry.items << item2
    assert entry.save!
  end
  
  test "get amount for category should return 0 when there is no item for this category" do
    entry = Entry.create
    category = categories(:one)

    assert_equal(0, entry.get_amount_for_category(category))
  end

  test "get amount for category should return 0 when item for this category has nil amount" do
    entry = Entry.create
    category = categories(:one)
    item = Item.create(:category => category, :amount => nil)
    entry.items << item

    assert_equal(0, entry.get_amount_for_category(category))
  end

  test "get amount for category should return nonzero value when such item exists" do
    entry = Entry.create
    category = categories(:one)
    item = Item.create(:category => category, :amount => 5)
    entry.items << item

    assert_equal(5, entry.get_amount_for_category(category))
  end

  test "should not allow entry being both income and expense" do
    #given
    entry = Entry.create
    entry.journal = journals(:finance_2012)
    income_item = Item.create(:category => categories(:two), :amount => 1)
    expense_item = Item.create(:category => categories(:five), :amount => 1)

    #when
    entry.items << income_item << expense_item

    #then
    assert_raise(ActiveRecord::RecordInvalid){
      entry.save!
    }
  end

  test "should save entry when the journal is opened" do
    entry = entries(:expense_one)
    entry.journal.is_open = true

    assert entry.save!
  end

  test "should not save entry when the journal is closed" do
    entry = entries(:expense_one)
    entry.journal.is_open = false
    entry.journal.blocked_to = Date.new(entry.journal.year).end_of_year

    assert_raise(ActiveRecord::RecordInvalid){
      entry.save!
    }
  end

  test "should not add entry when the journal is closed" do
    entry = Entry.create
    category = categories(:one)
    item = Item.create(:category => category, :amount => 5)
    entry.items << item
    entry.journal = journals(:finance_2012)
    entry.journal.is_open = false

    assert_raise(ActiveRecord::RecordInvalid){
      entry.save!
    }
  end

  test "should not delete entry when the journal is closed" do
    entry = entries(:expense_one)
    journal = entry.journal
    journal.is_open = false
    journal.blocked_to = Date.new(journal.year).end_of_year

    assert_no_difference('journal.entries.count') {
      entry.destroy
    }
  end

  test "should count sum of items" do
    entry = entries(:expense_one)

    expected_sum = 0
    Item.where(entry: entry).each do |item|
      expected_sum += item.amount
    end

    assert_equal expected_sum, entry.sum
  end

  test "linked entry sum must match" do
    #given
    entry = entries(:expense_one)
    entry.items = [Item.create(:category => categories(:five), :amount => 100)]
    linked = entries(:income_one)
    linked.items = [Item.create(:category => categories(:two), :amount => 200)]

    #when
    entry.linked_entry = linked
    
    #then    
    assert_raise(ActiveRecord::RecordInvalid){
      entry.save!
    }
  end

  test "income cannot be linked to income" do
    #given
    entry = entries(:expense_one)
    entry.items = [Item.create(:category => categories(:five), :amount => 100)]
    linked = entries(:expense_two)
    linked.items = [Item.create(:category => categories(:two), :amount => 100)]

    #when
    entry.linked_entry = linked
    
    #then    
    assert_raise(ActiveRecord::RecordInvalid){
      entry.save!
    }
  end

  test "should count income sum one percent for category" do
    #given
    entry = entries(:income_one)

    #when
    expected_amount = entry.items.select{|item| item.category.is_one_percent}.sum(&:amount_one_percent)

    #then
    assert_not_equal 0, expected_amount
    assert_equal expected_amount, entry.sum_one_percent
  end

  test "should create subentries for bank journal entries" do
    # Setup
    journal = journals(:bank_journal)
    entry = Entry.new(
      journal: journal,
      date: Date.today,
      name: "Test Entry with Subentries",
      document_number: "DOC123",
      statement_number: "STMT123",
      is_expense: false
    )
    
    # Add a category item
    category = categories(:one)
    entry.items.build(category: category, amount: 100.0)
    
    # Save the main entry
    assert entry.save, "Failed to save the main entry"
    
    # Verify entry can have subentries
    assert entry.can_have_subentries?, "Entry should be able to have subentries"
    
    # Create subentries
    entry.update_subentries(2) # Create 2 subentries (b and c)
    
    # Verify subentries were created
    assert_equal 2, entry.subentries.count, "Should have 2 subentries"
    assert_equal 3, entry.subentries_count, "Subentries count should be 3 (including main entry)"
    
    # Verify subentry properties
    subentry = entry.subentries.first
    assert subentry.is_subentry, "Subentry should have is_subentry=true"
    assert_equal entry.id, subentry.parent_entry_id, "Subentry should reference parent entry"
    assert_not_nil subentry.subentry_position, "Subentry should have a position"
  end
  
  test "should not create subentries for non-bank journal entries" do
    # Setup
    journal = journals(:finance_journal)
    entry = Entry.new(
      journal: journal,
      date: Date.today,
      name: "Test Entry",
      document_number: "DOC123",
      is_expense: false
    )
    
    # Add a category item
    category = categories(:one)
    entry.items.build(category: category, amount: 100.0)
    
    # Save the entry
    assert entry.save, "Failed to save the entry"
    
    # Verify entry cannot have subentries
    assert_not entry.can_have_subentries?, "Finance entry should not be able to have subentries"
    
    # Try to create subentries
    entry.update_subentries(2)
    
    # Verify no subentries were created
    assert_equal 0, entry.subentries.count, "Should have no subentries"
  end
  
  test "should update subentries count correctly" do
    # Setup
    journal = journals(:bank_journal)
    entry = Entry.new(
      journal: journal,
      date: Date.today,
      name: "Test Entry with Subentries",
      document_number: "DOC123",
      statement_number: "STMT123",
      is_expense: false
    )
    
    # Add a category item
    category = categories(:one)
    entry.items.build(category: category, amount: 100.0)
    
    # Save the main entry
    assert entry.save, "Failed to save the main entry"
    
    # Create 2 subentries
    entry.update_subentries(2)
    assert_equal 2, entry.subentries.count, "Should have 2 subentries"
    
    # Increase to 3 subentries
    entry.update_subentries(3)
    assert_equal 3, entry.subentries.count, "Should have 3 subentries"
    
    # Decrease to 1 subentry
    entry.update_subentries(1)
    assert_equal 1, entry.subentries.count, "Should have 1 subentry"
    
    # Remove all subentries
    entry.update_subentries(0)
    assert_equal 0, entry.subentries.count, "Should have no subentries"
  end

end
