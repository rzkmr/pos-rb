class CreateInvoices < ActiveRecord::Migration[8.1]
  def up
    create_table :invoices do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :table_session, null: false, foreign_key: true
      t.string :number, null: false
      t.string :financial_year, null: false
      t.integer :sequence, null: false
      t.datetime :issued_at, null: false
      t.integer :taxable_paise, null: false
      t.integer :cgst_paise, null: false
      t.integer :sgst_paise, null: false
      t.integer :round_off_paise, null: false, default: 0
      t.integer :total_paise, null: false
      t.string :gstin_snapshot
      t.string :customer_name
      t.string :customer_gstin
      t.datetime :printed_at
      t.integer :print_count, null: false, default: 0

      t.timestamps
    end

    add_index :invoices, :number, unique: true
    add_index :invoices, [ :shop_id, :financial_year, :sequence ], unique: true
  end

  def down
    drop_table :invoices
  end
end
