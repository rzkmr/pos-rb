# A parked, unsubmitted cart at a takeaway counter (design_system §8 —
# "Hold" / "Held orders"). Deliberately not a TableSession/Ticket: nothing
# should fire to the kitchen or reserve an invoice number until the cart
# is restored and actually charged. See HeldCart for the items snapshot shape.
class CreateHeldCarts < ActiveRecord::Migration[8.1]
  def up
    create_table :held_carts do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :dining_table, null: false, foreign_key: true
      t.references :held_by, null: false, foreign_key: { to_table: :users }
      t.json :items, null: false, default: []
      t.datetime :held_at, null: false

      t.timestamps
    end

    add_index :held_carts, [ :shop_id, :dining_table_id ]
  end

  def down
    drop_table :held_carts
  end
end
