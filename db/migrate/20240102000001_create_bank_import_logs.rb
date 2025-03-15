class CreateBankImportLogs < ActiveRecord::Migration
  def change
    create_table :bank_import_logs do |t|
      t.references :user, null: false, index: true
      t.references :unit, null: false, index: true
      t.string :file_name
      t.string :account_number
      t.integer :year
      t.integer :success_count, default: 0
      t.integer :error_count, default: 0
      t.text :error_messages
      t.string :ip_address
      t.datetime :import_date

      t.timestamps null: false
    end
  end
end 