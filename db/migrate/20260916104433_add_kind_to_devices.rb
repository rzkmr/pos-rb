class AddKindToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :kind, :string, null: false, default: "counter"
  end
end
