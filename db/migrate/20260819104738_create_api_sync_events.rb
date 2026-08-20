class CreateApiSyncEvents < ActiveRecord::Migration[8.1]
  def up
    # Cursor-based delta feed for the native/API client (Api::V1::DeltaController).
    # `seq` is a per-shop monotonic integer, never a timestamp — timestamp
    # pagination drops rows written in the same millisecond and breaks
    # under clock skew (API-SPEC.md §0, §3). A row here is a tombstone-
    # capable append-only log entry; the underlying entity tables are
    # never queried directly for "what changed since cursor X".
    create_table :api_sync_events do |t|
      t.references :shop, null: false, foreign_key: true
      t.bigint :seq, null: false
      t.string :entity, null: false
      t.string :action, null: false
      t.bigint :record_id, null: false
      t.jsonb :record, null: false, default: {}

      t.timestamps
    end

    add_index :api_sync_events, [ :shop_id, :seq ], unique: true

    # Per-shop counter that hands out the next seq. A separate row (not
    # MAX(seq)+1) so allocation can happen under a row lock without
    # scanning api_sync_events.
    add_column :shops, :api_sync_cursor, :bigint, null: false, default: 0
  end

  def down
    remove_column :shops, :api_sync_cursor
    drop_table :api_sync_events
  end
end
