module Sync
  module Handlers
    # Mirrors TableSessionsController#create's find-or-create — opening a
    # table that's already open is not an error, it's the normal case of a
    # second waiter reaching the same table (API-SPEC.md §7: "Multiple
    # devices add tickets to one session. Allowed."). Only genuinely
    # conflicting opens (two DIFFERENT sessions racing to open the SAME
    # table) need the session_exists rejection path; find-or-create here
    # already prevents that at the DB level rather than detecting it after
    # the fact.
    class OpenTableSession
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @user = user
        @payload = payload
      end

      def call
        dining_table = @shop.dining_tables.find(@payload.fetch("dining_table_id"))
        table_session = dining_table.open_session || dining_table.table_sessions.create!(
          opened_by: @user,
          opened_at: Time.current,
          status: "open"
        )

        { table_session_id: table_session.id, status: table_session.status }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
