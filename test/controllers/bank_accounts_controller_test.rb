require 'test_helper'

class BankAccountsControllerTest < ActionController::TestCase
  setup do
    @user = users(:admin)
    sign_in @user
    @unit = units(:troop_1zgm)
    @unit.update(bank_account: "12345678901234567890123456", auto_bank_import: true)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:units)
  end

  test "should get upload_associations page" do
    get :upload_associations
    assert_response :success
    assert_not_nil assigns(:unit_accounts)
  end

  test "should process associations from CSV" do
    csv_content = "troop_1zgm,11114444555566667777888899\ntroop_2zgm,99998888777766665555444411"
    file = Tempfile.new(['test', '.csv'])
    file.write(csv_content)
    file.rewind

    # Symulacja przesłanego pliku
    csv_file = Rack::Test::UploadedFile.new(file.path, 'text/csv')
    
    post :process_associations, csv_file: csv_file
    
    assert_redirected_to bank_accounts_path
    assert_equal 'Numery kont zostały zaktualizowane', flash[:notice]
    
    # Sprawdź czy numery kont zostały zaktualizowane
    @unit.reload
    assert_equal "11114444555566667777888899", @unit.bank_account
    
    unit2 = units(:troop_2zgm)
    assert_equal "99998888777766665555444411", unit2.bank_account
    assert_equal true, unit2.auto_bank_import
  end

  test "should reject empty CSV file" do
    post :process_associations
    assert_redirected_to upload_associations_bank_accounts_path
    assert_equal 'Nie wybrano pliku CSV', flash[:alert]
  end

  test "should get upload_elixir page" do
    get :upload_elixir
    assert_response :success
  end

  test "should toggle auto_import status" do
    original_status = @unit.auto_bank_import
    
    post :toggle_auto_import, unit_id: @unit.id
    
    @unit.reload
    assert_equal !original_status, @unit.auto_bank_import
    assert_redirected_to bank_accounts_path
  end

  test "should get clear_journal_entries page" do
    journal = @unit.journals.create!(year: Date.today.year, journal_type_id: JournalType::BANK_TYPE_ID, is_open: true)
    
    get :clear_journal_entries, unit_id: @unit.id, year: Date.today.year
    
    assert_response :success
    assert_equal @unit, assigns(:unit)
    assert_equal Date.today.year, assigns(:year)
  end

  test "should perform clear journal entries" do
    journal = @unit.journals.create!(year: Date.today.year, journal_type_id: JournalType::BANK_TYPE_ID, is_open: true)
    entry = journal.entries.create!(date: Date.today, document_number: "TEST-001")
    
    post :perform_clear_journal_entries, unit_id: @unit.id, year: Date.today.year
    
    assert_redirected_to bank_accounts_path
    assert_match /Usunięto \d+ wpisów/, flash[:notice]
    assert_equal 0, journal.reload.entries.count
  end

  test "should not clear journal entries for closed journal" do
    journal = @unit.journals.create!(year: Date.today.year, journal_type_id: JournalType::BANK_TYPE_ID, is_open: false)
    entry = journal.entries.create!(date: Date.today, document_number: "TEST-001")
    
    post :perform_clear_journal_entries, unit_id: @unit.id, year: Date.today.year
    
    assert_redirected_to bank_accounts_path
    assert_match /jest zamknięta/, flash[:alert]
    assert_equal 1, journal.reload.entries.count
  end
end 