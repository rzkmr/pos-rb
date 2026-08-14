class RemoveKindFromDevices < ActiveRecord::Migration[8.1]
  def up
    remove_column :devices, :kind
  end

  def down
    add_column :devices, :kind, :string, null: false, default: "waiter"
    change_column_default :devices, :kind, from: "waiter", to: nil
  end
end
