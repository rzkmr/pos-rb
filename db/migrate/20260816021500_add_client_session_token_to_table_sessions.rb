class AddClientSessionTokenToTableSessions < ActiveRecord::Migration[8.1]
  def change
    # A cold-started offline sale (the offline shell, never having reached
    # the server) has no real TableSession id to submit against — it can
    # only generate a random token client-side. TableSession.resolve_for_takeaway!
    # finds-or-creates the real session from this token, so a replayed
    # action or a re-reported invoice always resolves to the SAME session
    # instead of creating a duplicate. Mirrors tickets.client_token exactly
    # (CLAUDE.md invariant #2). Nullable: every existing row and the normal
    # server-rendered flow never set this.
    add_column :table_sessions, :client_session_token, :string
    add_index :table_sessions, [ :shop_id, :client_session_token ], unique: true,
      where: "client_session_token IS NOT NULL", name: "idx_table_sessions_on_shop_and_client_token"
  end
end
