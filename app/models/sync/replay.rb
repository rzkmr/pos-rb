# Dispatches one queued client action to its handler, wrapped in the
# client_actions idempotency ledger (see db/migrate/*_create_client_actions).
# A replayed client_action_id returns the stored result without re-running
# the handler — this is what makes draining the same outbox batch twice
# safe (a reload mid-drain, a retried POST, ...).
module Sync
  class Replay
    HANDLERS = {
      "submit_ticket" => Sync::Handlers::SubmitTicket,
      "takeaway_checkout" => Sync::Handlers::TakeawayCheckout,
      "void_ticket_item" => Sync::Handlers::VoidTicketItem,
      "apply_discount" => Sync::Handlers::ApplyDiscount,
      "record_payment" => Sync::Handlers::RecordPayment,
      "reprint_invoice" => Sync::Handlers::ReprintInvoice,
      "update_ticket_status" => Sync::Handlers::UpdateTicketStatus,
      "open_table_session" => Sync::Handlers::OpenTableSession,
      "close_table_session" => Sync::Handlers::CloseTableSession,
      "issue_invoice" => Sync::Handlers::IssueInvoice
    }.freeze

    def self.call(shop:, device:, user:, client_action_id:, kind:, payload:)
      new(shop: shop, device: device, user: user, client_action_id: client_action_id, kind: kind, payload: payload).call
    end

    def initialize(shop:, device:, user:, client_action_id:, kind:, payload:)
      @shop = shop
      @device = device
      @user = user
      @client_action_id = client_action_id
      @kind = kind
      @payload = payload
    end

    def call
      existing = ClientAction.find_by(shop: @shop, client_action_id: @client_action_id)
      return { client_action_id: @client_action_id, status: "duplicate", result: existing.result } if existing

      handler_class = HANDLERS[@kind]
      return { client_action_id: @client_action_id, status: "rejected", error: "unknown kind: #{@kind}" } unless handler_class

      ActiveRecord::Base.transaction(requires_new: true) do
        result = handler_class.new(shop: @shop, device: @device, user: @user, payload: @payload).call
        ClientAction.create!(
          shop: @shop, device: @device, client_action_id: @client_action_id,
          kind: @kind, status: "applied", result: result, applied_at: Time.current
        )
        { client_action_id: @client_action_id, status: "applied", result: result }
      end
    rescue Sync::Handlers::Rejected => e
      { client_action_id: @client_action_id, status: "rejected", error: e.message }
    end
  end
end
