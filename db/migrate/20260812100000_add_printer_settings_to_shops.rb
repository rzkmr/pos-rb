class AddPrinterSettingsToShops < ActiveRecord::Migration[8.1]
  def up
    add_column :shops, :printer_host, :string
    add_column :shops, :printer_port, :integer, null: false, default: 9100
  end

  def down
    remove_column :shops, :printer_port
    remove_column :shops, :printer_host
  end
end
