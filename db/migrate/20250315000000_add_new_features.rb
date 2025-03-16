class AddNewFeatures < ActiveRecord::Migration[5.2]
  def change
    # Add bank account to units (from AddBankAccountToUnits)
    add_column :units, :bank_account, :string unless column_exists?(:units, :bank_account)
    add_column :units, :auto_bank_import, :boolean, default: false unless column_exists?(:units, :auto_bank_import)
    
    # Add document date to entries (from AddDocumentDateToEntries)
    add_column :entries, :document_date, :date unless column_exists?(:entries, :document_date)
    
    # Add subentries support (from AddSubentriesToEntries)
    unless column_exists?(:entries, :parent_entry_id)
      add_column :entries, :parent_entry_id, :integer, null: true
      add_index :entries, :parent_entry_id
    end
    
    unless column_exists?(:entries, :is_subentry)
      add_column :entries, :is_subentry, :boolean, default: false
      add_index :entries, :is_subentry
    end
    
    unless column_exists?(:entries, :subentry_position)
      add_column :entries, :subentry_position, :string, null: true
    end
    
    unless column_exists?(:entries, :subentries_count)
      add_column :entries, :subentries_count, :integer, default: 0
    end
    
    # Add statement number to entries (from AddStatementNumberToEntries)
    add_column :entries, :statement_number, :string unless column_exists?(:entries, :statement_number)
  end
end 