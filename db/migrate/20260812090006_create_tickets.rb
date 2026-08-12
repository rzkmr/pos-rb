class CreateTickets < ActiveRecord::Migration[8.1]
  def up
    create_table :tickets do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :table_session, null: false, foreign_key: true
      t.string :client_token, null: false
      t.integer :number, null: false
      t.references :placed_by, null: false, foreign_key: { to_table: :users }
      t.datetime :placed_at, null: false
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :tickets, :client_token, unique: true
    add_index :tickets, [ :shop_id, :status ]
  end

  def down
    drop_table :tickets
  end
end
