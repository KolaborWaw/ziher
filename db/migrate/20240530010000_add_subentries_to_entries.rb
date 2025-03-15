class AddSubentriesToEntries < ActiveRecord::Migration[5.2]
  def change
    # Sprawdzamy, czy kolumny już istnieją przed próbą ich dodania
    unless column_exists?(:entries, :parent_entry_id)
      add_column :entries, :parent_entry_id, :integer, null: true
      add_index :entries, :parent_entry_id unless index_exists?(:entries, :parent_entry_id)
    end
    
    unless column_exists?(:entries, :is_subentry)
      add_column :entries, :is_subentry, :boolean, default: false
      add_index :entries, :is_subentry unless index_exists?(:entries, :is_subentry)
    end
    
    unless column_exists?(:entries, :subentry_position)
      add_column :entries, :subentry_position, :string, null: true
    end
    
    unless column_exists?(:entries, :subentries_count)
      add_column :entries, :subentries_count, :integer, default: 1
    end
  end
end 