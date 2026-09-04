class CreateOwnerSessions < ActiveRecord::Migration[8.1]
  def up
    create_table :owner_sessions do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :owner_sessions, :token_digest, unique: true
  end

  def down
    drop_table :owner_sessions
  end
end
