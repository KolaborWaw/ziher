class AddBankAccountToUnits < ActiveRecord::Migration
  def change
    add_column :units, :bank_account, :string
    add_column :units, :auto_bank_import, :boolean, default: false
  end
end 