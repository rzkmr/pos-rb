# The idempotency ledger for every offline-queued write. See
# Sync::ActionsController and Sync::Replay — a replayed client_action_id
# returns the stored result instead of re-applying the action.
class ClientAction < ApplicationRecord
  include ShopScoped

  belongs_to :device, optional: true

  validates :client_action_id, presence: true, uniqueness: { scope: :shop_id }
  validates :kind, presence: true
  validates :status, presence: true
end
