class CreateUsers < ActiveRecord::Migration[8.1]
  def up
    create_table :users do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :name, null: false
      t.string :pin_digest, null: false
      t.string :role, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :users, [ :shop_id, :role ]
  end

  def down
    drop_table :users
  end
end
