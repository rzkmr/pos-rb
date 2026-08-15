# Computes GST on the session subtotal (never per line — CLAUDE.md invariant #7)
# and issues the gapless per-financial-year invoice (invariant #5).
class Billing
  Result = Struct.new(:taxable_paise, :cgst_paise, :sgst_paise, :round_off_paise, :total_paise, keyword_init: true)

  # Raised when a device holds live offline invoice authority for this shop
  # (see InvoiceAuthority) — issuing an invoice from anywhere else while
  # that's true would create two writers for the same number sequence,
  # exactly what invariant #5 forbids. rescue_from in ApplicationController
  # turns this into a plain, non-technical message for whoever hit it.
  class InvoiceAuthorityHeld < StandardError
    attr_reader :grant

    def initialize(grant)
      @grant = grant
      super("Invoice authority is held by #{grant.device.label} since #{grant.granted_at}")
    end
  end

  def self.compute(shop:, taxable_paise:)
    return Result.new(taxable_paise: taxable_paise, cgst_paise: 0, sgst_paise: 0, round_off_paise: 0, total_paise: taxable_paise) if shop.composition_scheme

    half_rate_bp = shop.gst_rate_bp / 2.0
    cgst_paise = (taxable_paise * half_rate_bp / 10_000).round
    sgst_paise = cgst_paise

    pre_round_total = taxable_paise + cgst_paise + sgst_paise
    total_paise = (pre_round_total / 100.0).round * 100
    round_off_paise = total_paise - pre_round_total

    Result.new(
      taxable_paise: taxable_paise,
      cgst_paise: cgst_paise,
      sgst_paise: sgst_paise,
      round_off_paise: round_off_paise,
      total_paise: total_paise
    )
  end

  # already_printed_at is set by Sync::OfflineInvoiceIngest — the receipt
  # was already handed to the customer at the offline counter, so this
  # skips queuing a fresh print job (which would reprint a whole shift's
  # receipts the moment the device reconnects) and stamps the invoice
  # printed at the time it was actually printed, offline, instead.
  def self.issue_invoice!(table_session:, already_printed_at: nil)
    shop = table_session.shop

    grant = InvoiceAuthority.live_for(shop)
    raise InvoiceAuthorityHeld, grant if grant && !InvoiceAuthority.ingesting?

    result = compute(shop: shop, taxable_paise: table_session.subtotal_paise)
    financial_year = Shop.financial_year_for(Date.current)

    invoice = shop.with_lock do
      sequence = shop.next_invoice_sequence!(financial_year)
      table_session.invoices.create!(
        shop: shop,
        number: "#{shop.invoice_prefix}/#{financial_year}/#{sequence.to_s.rjust(5, '0')}",
        financial_year: financial_year,
        sequence: sequence,
        issued_at: Time.current,
        taxable_paise: result.taxable_paise,
        cgst_paise: result.cgst_paise,
        sgst_paise: result.sgst_paise,
        round_off_paise: result.round_off_paise,
        total_paise: result.total_paise,
        gstin_snapshot: shop.gstin,
        printed_at: already_printed_at,
        print_count: already_printed_at ? 1 : 0
      )
    end

    Printing.enqueue_invoice!(invoice) unless already_printed_at
    invoice
  end

  # Records one payment and, if it brings the session to fully paid, issues
  # the invoice and closes the session out — the shared settle path used by
  # both the itemized payment form and the one-tap takeaway checkout.
  #
  # client_token is optional (nil for the normal in-browser form submit,
  # which Rails' own CSRF/double-submit protections already cover) but
  # required for anything going through the offline write queue (see
  # Sync::Handlers::RecordPayment) — a replayed queue entry must not
  # double-credit the session. requires_new: true mirrors Ticket.submit!'s
  # reasoning: without a savepoint, a RecordNotUnique here would poison the
  # whole enclosing transaction, not just this insert.
  #
  # already_printed_at forwards straight to issue_invoice! — see there.
  def self.record_payment_and_settle!(table_session:, method:, amount_paise:, received_by:, reference: nil, client_token: nil, already_printed_at: nil)
    shop = table_session.shop
    invoice = nil

    ActiveRecord::Base.transaction(requires_new: true) do
      table_session.payments.create!(
        shop: shop,
        method: method,
        amount_paise: amount_paise,
        reference: reference,
        received_by: received_by,
        client_token: client_token
      )

      result = compute(shop: shop, taxable_paise: table_session.subtotal_paise)
      if table_session.paid_paise >= result.total_paise
        invoice = issue_invoice!(table_session: table_session, already_printed_at: already_printed_at) if table_session.invoices.none?
        table_session.update!(status: "paid", closed_at: Time.current)
      end
    end

    invoice
  rescue ActiveRecord::RecordNotUnique
    raise if client_token.nil?

    table_session.payments.find_by!(client_token: client_token)
    table_session.invoices.first
  end
end
