# Extracts VAT and service charge backward out of the session's gross
# total (never adds tax on top — menu prices are gross/tax-inclusive,
# CLAUDE.md invariant #2) and issues the gapless per-BS-fiscal-year
# invoice (invariant #9).
#
# Extraction order is fixed and computed on the session total, never per
# line (invariant #3): VAT comes out first because it's the statutory
# figure; base and service charge are residuals, which is what guarantees
# base + service_charge + vat == gross exactly, in paisa, every time.
class Billing
  Result = Struct.new(:base_paisa, :service_charge_paisa, :vat_paisa, :gross_paisa, keyword_init: true)

  # Raised when a device holds live offline invoice authority for this shop
  # (see InvoiceAuthority) — issuing an invoice from anywhere else while
  # that's true would create two writers for the same number sequence,
  # exactly what invariant #9 forbids. rescue_from in ApplicationController
  # turns this into a plain, non-technical message for whoever hit it.
  class InvoiceAuthorityHeld < StandardError
    attr_reader :grant

    def initialize(grant)
      @grant = grant
      super("Invoice authority is held by #{grant.device.label} since #{grant.granted_at}")
    end
  end

  # gross_paisa is the session subtotal exactly as guests are charged —
  # menu prices are already tax-inclusive, so this is never multiplied up,
  # only decomposed. VAT rate and service charge rate come from the shop's
  # own settings (defaults 13%/10%, CLAUDE.md), not hardcoded, so a rate
  # change never needs a code deploy.
  def self.compute(shop:, gross_paisa:)
    taxable_before_vat = (gross_paisa / (1 + shop.vat_rate_bp / 10_000.0)).round
    vat_paisa = gross_paisa - taxable_before_vat

    base_paisa = (taxable_before_vat / (1 + shop.service_charge_rate_bp / 10_000.0)).round
    service_charge_paisa = taxable_before_vat - base_paisa

    Result.new(
      base_paisa: base_paisa,
      service_charge_paisa: service_charge_paisa,
      vat_paisa: vat_paisa,
      gross_paisa: gross_paisa
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

    result = compute(shop: shop, gross_paisa: table_session.subtotal_paisa)
    financial_year = BikramSambat.fiscal_year_for(Date.current)

    invoice = shop.with_lock do
      sequence = shop.next_invoice_sequence!(financial_year)
      table_session.invoices.create!(
        shop: shop,
        number: "#{shop.invoice_prefix}/#{financial_year}/#{sequence.to_s.rjust(5, '0')}",
        financial_year: financial_year,
        sequence: sequence,
        issued_at: Time.current,
        base_paisa: result.base_paisa,
        service_charge_paisa: result.service_charge_paisa,
        vat_paisa: result.vat_paisa,
        gross_paisa: result.gross_paisa,
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
  def self.record_payment_and_settle!(table_session:, method:, amount_paisa:, received_by:, reference: nil, client_token: nil, already_printed_at: nil)
    shop = table_session.shop
    invoice = nil

    ActiveRecord::Base.transaction(requires_new: true) do
      table_session.payments.create!(
        shop: shop,
        method: method,
        amount_paisa: amount_paisa,
        reference: reference,
        received_by: received_by,
        client_token: client_token
      )

      result = compute(shop: shop, gross_paisa: table_session.subtotal_paisa)
      if table_session.paid_paisa >= result.gross_paisa
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
