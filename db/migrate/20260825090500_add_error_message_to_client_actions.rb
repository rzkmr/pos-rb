class AddErrorMessageToClientActions < ActiveRecord::Migration[8.1]
  # client_actions.status was, until now, only ever "applied" — a
  # terminally rejected operation raised Sync::Handlers::Rejected and left
  # no server-side row at all, so there was nothing an admin screen could
  # ever list. Persisting "rejected" rows (with the handler's message) is
  # what a future failed-operation queue (ARCHITECTURE.md §12) will read.
  # applied_at becomes nullable because a rejected op was never applied.
  def change
    add_column :client_actions, :error_message, :string
    change_column_null :client_actions, :applied_at, true
  end
end
