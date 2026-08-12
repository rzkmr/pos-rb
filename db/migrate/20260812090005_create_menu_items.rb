class CreateMenuItems < ActiveRecord::Migration[8.1]
  def up
    create_table :menu_items do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category, null: false
      t.integer :price_paise, null: false
      t.json :variants, null: false, default: []
      t.string :hsn_sac, null: false, default: "996331"
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :menu_items, [ :shop_id, :active ]
  end

  def down
    drop_table :menu_items
  end
end
