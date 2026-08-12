class AddAdminPinDigestToShops < ActiveRecord::Migration[8.1]
  def up
    add_column :shops, :admin_pin_digest, :string, null: false, default: ""
  end

  def down
    remove_column :shops, :admin_pin_digest
  end
end
