# The pairing PIN is a shared operational secret handed out verbally by
# admin to staff pairing a new device — same trust model as a WiFi
# password, not a personal credential. Hashing it meant nobody, not even
# admin, could ever look it up again after setting it, which made the
# actual "how does staff find out the PIN" question unanswerable inside
# the app. Storing it in the clear lets Settings display it plainly.
class ConvertShopPairingPinToPlaintext < ActiveRecord::Migration[8.1]
  def up
    add_column :shops, :pairing_pin, :string
    remove_column :shops, :admin_pin_digest, :string
  end

  def down
    add_column :shops, :admin_pin_digest, :string, default: "", null: false
    remove_column :shops, :pairing_pin, :string
  end
end
