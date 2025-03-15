class AddDocumentDateToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :document_date, :date
  end
end 