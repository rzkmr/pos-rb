class CreateAdminUsers < ActiveRecord::Migration[8.1]
  def up
    create_table :admin_users do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :username, null: false
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.timestamps

      t.index [ :shop_id, :username ], unique: true
    end

    add_reference :audit_events, :admin_user, foreign_key: true
    change_column_null :audit_events, :user_id, true
  end

  def down
    change_column_null :audit_events, :user_id, false
    remove_reference :audit_events, :admin_user, foreign_key: true
    drop_table :admin_users
  end
end
