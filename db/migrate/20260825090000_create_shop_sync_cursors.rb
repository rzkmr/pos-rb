class CreateShopSyncCursors < ActiveRecord::Migration[8.1]
  # `shops.api_sync_cursor` blocks Shop from ever including ApiSyncEmitting
  # (bumping the counter is itself a write to `shops`, which would re-enter
  # ApiSyncEmitting's after_commit forever) — but the API spec requires shop
  # upserts in the delta stream (service_charge_enabled flips, fiscal-year
  # rollover). Moving the counter to its own row-locked table breaks that
  # recursion: incrementing shop_sync_cursors is no longer a write to shops.
  def up
    create_table :shop_sync_cursors do |t|
      t.references :shop, null: false, foreign_key: true, index: { unique: true }
      t.bigint :value, null: false, default: 0

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO shop_sync_cursors (shop_id, value, created_at, updated_at)
          SELECT id, api_sync_cursor, NOW(), NOW() FROM shops
        SQL
      end
    end

    remove_column :shops, :api_sync_cursor
  end

  def down
    add_column :shops, :api_sync_cursor, :bigint, null: false, default: 0

    execute <<~SQL
      UPDATE shops SET api_sync_cursor = shop_sync_cursors.value
      FROM shop_sync_cursors WHERE shop_sync_cursors.shop_id = shops.id
    SQL

    drop_table :shop_sync_cursors
  end
end
