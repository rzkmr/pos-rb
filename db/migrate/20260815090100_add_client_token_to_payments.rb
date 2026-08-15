class AddClientTokenToPayments < ActiveRecord::Migration[8.1]
  def change
    # Payments had no idempotency key at all — a replayed record_payment
    # action (offline retry, or a duplicate outbox drain) would double-
    # credit the session and could wrongly settle it. Nullable because
    # existing rows and any future non-queued payment path have no client
    # token; the partial unique index only guards rows that do.
    add_column :payments, :client_token, :string
    add_index :payments, :client_token, unique: true, where: "client_token IS NOT NULL"
  end
end
