# Tracks every device-pairing attempt (success or failure) against the
# shop's pairing PIN — a 4-digit, 10,000-combination secret that only a
# per-IP rate limit protected before this. Failed attempts had no trace
# at all: admin could not see a brute-force in progress, and nothing
# stopped an attacker who rotated source IPs from grinding through the
# whole keyspace at the per-IP limit's full rate. This table backs both
# a shop-wide lockout (count recent failures regardless of IP) and
# visibility into it after the fact.
class CreatePairingAttempts < ActiveRecord::Migration[8.1]
  def up
    create_table :pairing_attempts do |t|
      t.references :shop, null: false, foreign_key: true
      t.boolean :success, null: false
      t.string :ip_address, null: false
      t.timestamps
    end

    add_index :pairing_attempts, [ :shop_id, :success, :created_at ]
  end

  def down
    drop_table :pairing_attempts
  end
end
