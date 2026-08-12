class CreateDevices < ActiveRecord::Migration[8.1]
  def up
    create_table :devices do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :label, null: false
      t.string :token_digest, null: false
      t.string :kind, null: false
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :devices, :token_digest, unique: true
  end

  def down
    drop_table :devices
  end
end
