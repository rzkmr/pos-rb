class AddLocaleToUsersAndAdminUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :locale, :string, null: false, default: "ne"
    add_column :admin_users, :locale, :string, null: false, default: "en"
  end

  def down
    remove_column :admin_users, :locale
    remove_column :users, :locale
  end
end
