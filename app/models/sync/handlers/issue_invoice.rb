module Sync
  module Handlers
    # A fiscal document may never trust client arithmetic (API-SPEC.md §0,
    # §6) — this handler recomputes tax from the session's own line items
    # and compares against what the client reports before issuing
    # anything. A mismatch is a Rejected (non-retryable): the client must
    # not auto-correct and resubmit, because if it printed a physical
    # receipt already this is now a human problem, not a sync problem. The
    # actual invoice number/sequence always comes from
    # Billing.issue_invoice! (the shop's own gapless counter, CLAUDE.md
    # invariant #5) — the client-reported number in the payload is
    # validated, never assigned.
    class IssueInvoice
      def initialize(shop:, device:, user:, payload:)
        @shop = shop
        @payload = payload
      end

      def call
        table_session = @shop.table_sessions.find(@payload.fetch("table_session_id"))
        return { invoice_id: table_session.invoices.first.id, number: table_session.invoices.first.number } if table_session.invoices.any?

        computed = Billing.compute(shop: @shop, taxable_paise: table_session.subtotal_paise)
        reported_total = @payload["total_paise"] || @payload["gross_paisa"]

        if reported_total && reported_total != computed.total_paise
          raise Sync::Handlers::Rejected, "tax_mismatch: server computed #{computed.total_paise}, client reported #{reported_total}"
        end

        invoice = Billing.issue_invoice!(table_session: table_session)
        { invoice_id: invoice.id, number: invoice.number, total_paise: invoice.total_paise }
      rescue ActiveRecord::RecordNotFound => e
        raise Sync::Handlers::Rejected, e.message
      rescue Billing::InvoiceAuthorityHeld => e
        raise Sync::Handlers::Rejected, e.message
      end
    end
  end
end
