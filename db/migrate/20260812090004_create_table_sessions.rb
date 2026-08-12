class CreateTableSessions < ActiveRecord::Migration[8.1]
  def up
    create_table :table_sessions do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :dining_table, null: false, foreign_key: true
      t.references :opened_by, null: false, foreign_key: { to_table: :users }
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.string :status, null: false, default: "open"
      t.integer :discount_paise, null: false, default: 0
      t.string :discount_reason
      t.references :discount_approved_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :table_sessions, [ :shop_id, :status ]
  end

  def down
    drop_table :table_sessions
  end
end
