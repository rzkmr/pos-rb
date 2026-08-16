module Sync
  module Handlers
    # Mirrors TakeawayCheckoutsController#create exactly (ticket submit +
    # full payment in one transaction) so the counter's one-tap checkout
    # can go through the same offline write queue as everything else,
    # instead of keeping its own separate retry path. Reuses the ticket's
    # client_token for the payment too — this handler only ever represents
    # one checkout, so the two are 1:1.
    #
    # Accepts EITHER table_session_id (the normal, server-rendered online
    # path — an id that already exists) OR client_session_token (a cold-
    # started offline sale that has never talked to the server — see
    # TableSession.resolve_for_takeaway!, which finds-or-creates against
    # the shop's takeaway counter). Exactly one must be present.
    class TakeawayCheckout
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @user = user
        @payload = payload
      end

      def call
        acting_user = Sync::ActingUser.resolve!(shop: @shop, current_user: @user, payload: @payload)
        table_session = resolve_table_session(acting_user)
        client_token = @payload.fetch("client_token")
        items_attributes = @payload.fetch("items").map do |item|
          { menu_item_id: item.fetch("menu_item_id"), quantity: item.fetch("quantity"), notes: item["notes"] }
        end

        ActiveRecord::Base.transaction do
          Ticket.submit!(
            table_session: table_session,
            client_token: client_token,
            placed_by: acting_user,
            items_attributes: items_attributes
          )

          if table_session.reload.status == "open"
            billing = Billing.compute(shop: @shop, taxable_paise: table_session.subtotal_paise)
            Billing.record_payment_and_settle!(
              table_session: table_session,
              method: @payload.fetch("method"),
              amount_paise: billing.total_paise,
              received_by: acting_user,
              client_token: client_token
            )
          end
        end

        { table_session_id: table_session.id }
      rescue ActiveRecord::RecordNotFound, TableSession::NoTakeawayCounter, Sync::ActingUser::Unresolved => e
        raise Sync::Handlers::Rejected, e.message
      end

      private

      def resolve_table_session(acting_user)
        if @payload["client_session_token"]
          TableSession.resolve_for_takeaway!(
            shop: @shop, client_session_token: @payload.fetch("client_session_token"), opened_by: acting_user
          )
        else
          @shop.table_sessions.find(@payload.fetch("table_session_id"))
        end
      end
    end
  end
end
