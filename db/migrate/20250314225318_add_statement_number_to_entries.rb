class AddStatementNumberToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :statement_number, :string
  end
end
