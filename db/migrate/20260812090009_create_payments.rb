class CreatePayments < ActiveRecord::Migration[8.1]
  def up
    create_table :payments do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :table_session, null: false, foreign_key: true
      t.string :method, null: false
      t.integer :amount_paise, null: false
      t.string :reference
      t.references :received_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :payments, [ :shop_id, :table_session_id ]
  end

  def down
    drop_table :payments
  end
end
