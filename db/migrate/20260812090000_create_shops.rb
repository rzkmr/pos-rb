class CreateShops < ActiveRecord::Migration[8.1]
  def up
    create_table :shops do |t|
      t.string :name, null: false
      t.string :gstin
      t.string :address
      t.string :state_code, null: false
      t.string :fssai_licence
      t.boolean :prices_include_tax, null: false, default: false
      t.integer :gst_rate_bp, null: false, default: 500
      t.boolean :composition_scheme, null: false, default: false
      t.text :invoice_footer
      t.string :invoice_prefix, null: false, default: "INV"
      t.integer :invoice_sequence, null: false, default: 0
      t.string :invoice_fy, null: false

      t.timestamps
    end
  end

  def down
    drop_table :shops
  end
end
