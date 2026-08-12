class CreateDiningTables < ActiveRecord::Migration[8.1]
  def up
    create_table :dining_tables do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :label, null: false
      t.integer :seats, null: false, default: 4
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :dining_tables, [ :shop_id, :label ], unique: true
  end

  def down
    drop_table :dining_tables
  end
end
