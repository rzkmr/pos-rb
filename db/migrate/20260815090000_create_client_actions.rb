class CreateClientActions < ActiveRecord::Migration[8.1]
  def change
    # The idempotency ledger for every offline-queued write (void, discount,
    # payment, reprint, ticket status, ...). A replayed client_action_id
    # returns the stored result instead of re-applying — this generalizes
    # the same guarantee tickets.client_token already gives ticket
    # submission (CLAUDE.md invariant #2) to every other mutating action.
    create_table :client_actions do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :device, null: true, foreign_key: true
      t.string :client_action_id, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: "applied"
      t.jsonb :result, null: false, default: {}
      t.datetime :applied_at, null: false

      t.timestamps
    end

    add_index :client_actions, [ :shop_id, :client_action_id ], unique: true
    add_index :client_actions, [ :shop_id, :status ]
  end
end
