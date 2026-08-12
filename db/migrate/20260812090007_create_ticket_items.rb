class CreateTicketItems < ActiveRecord::Migration[8.1]
  def up
    create_table :ticket_items do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :menu_item, null: false, foreign_key: true
      t.string :name_snapshot, null: false
      t.string :variant_name
      t.string :hsn_sac_snapshot, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_paise, null: false
      t.text :notes
      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }
      t.string :void_reason

      t.timestamps
    end
  end

  def down
    drop_table :ticket_items
  end
end
