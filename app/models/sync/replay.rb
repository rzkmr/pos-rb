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
      "issue_invoice" => Sync::Handlers::IssueInvoice,
      "record_device_print" => Sync::Handlers::RecordDevicePrint
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
      return existing_outcome(existing) if existing

      handler_class = HANDLERS[@kind]
      return record_rejected!("unknown kind: #{@kind}") unless handler_class

      ActiveRecord::Base.transaction(requires_new: true) do
        result = handler_class.new(shop: @shop, device: @device, user: @user, payload: @payload).call
        ClientAction.create!(
          shop: @shop, device: @device, client_action_id: @client_action_id,
          kind: @kind, status: "applied", result: result, applied_at: Time.current
        )
        { client_action_id: @client_action_id, status: "applied", result: result }
      end
    rescue Sync::Handlers::Rejected => e
      record_rejected!(e.message)
    end

    private

    # A replayed op_id must not lose the fact that it was already rejected
    # (API-SPEC.md §4: rejected is terminal, the device must stop retrying)
    # — only an "applied" row is safe to report back as a plain duplicate.
    def existing_outcome(existing)
      if existing.status == "rejected"
        { client_action_id: @client_action_id, status: "rejected", error: existing.error_message }
      else
        { client_action_id: @client_action_id, status: "duplicate", result: existing.result }
      end
    end

    # Written outside the handler's own (rolled-back) transaction, on
    # purpose — a failed check's own record must survive the failure it
    # documents, the same reasoning Sync::OfflineInvoiceIngest's audit
    # trail already relies on. This is what makes a terminally rejected
    # op visible anywhere server-side instead of vanishing.
    def record_rejected!(message)
      ClientAction.create!(
        shop: @shop, device: @device, client_action_id: @client_action_id,
        kind: @kind, status: "rejected", error_message: message
      )
      { client_action_id: @client_action_id, status: "rejected", error: message }
    end
  end
end
