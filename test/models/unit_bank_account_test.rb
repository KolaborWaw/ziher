require 'test_helper'

class UnitBankAccountTest < ActiveSupport::TestCase
  setup do
    @unit = units(:troop_1zgm)
    @unit.update(bank_account: "12345678901234567890123456", auto_bank_import: true)
  end
  
  test "should store bank account number" do
    assert_equal "12345678901234567890123456", @unit.bank_account
  end
  
  test "should store auto_bank_import flag" do
    assert_equal true, @unit.auto_bank_import
  end
  
  test "should update bank account number" do
    @unit.update(bank_account: "98765432109876543210987654")
    @unit.reload
    assert_equal "98765432109876543210987654", @unit.bank_account
  end
  
  test "should toggle auto_bank_import flag" do
    original_value = @unit.auto_bank_import
    @unit.update(auto_bank_import: !original_value)
    @unit.reload
    assert_equal !original_value, @unit.auto_bank_import
  end
  
  test "should allow blank bank account" do
    @unit.update(bank_account: "")
    assert_equal "", @unit.bank_account
  end
  
  test "should not require bank account number" do
    @unit.bank_account = nil
    assert @unit.valid?
  end
  
  test "should update fixtures with new columns" do
    units = Unit.all
    units.each do |unit|
      if unit.bank_account.nil?
        assert_nil unit.bank_account
        assert_equal false, unit.auto_bank_import unless unit == @unit
      end
    end
  end
end 