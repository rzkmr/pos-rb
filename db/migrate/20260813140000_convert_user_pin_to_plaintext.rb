# Same reasoning as Shop#pairing_pin (see that migration): this is a
# shared-tablet PIN with no self-service reset. If a waiter forgets their
# PIN mid-shift, admin is the only recourse — and today that means
# forcing a NEW PIN on them (more disruptive) because the old one can
# never be looked up again once hashed. Storing it in the clear lets
# admin just read the current PIN back to them instead.
class ConvertUserPinToPlaintext < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :pin, :string
    remove_column :users, :pin_digest, :string
  end

  def down
    add_column :users, :pin_digest, :string, null: false, default: ""
    remove_column :users, :pin, :string
  end
end
