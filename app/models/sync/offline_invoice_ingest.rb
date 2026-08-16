# Turns a batch of client-side-issued offline invoices (lib/offline_invoice.js)
# into real, server-persisted Invoice rows, and advances the shop's
# authoritative counter to match — so the next SERVER-issued invoice
# continues the same gapless sequence with zero gap and zero duplicate.
#
# Every record is validated BEFORE anything is written — contiguity and tax
# checks both happen ahead of the shop-locked write transaction, not inside
# it, specifically so that a failed check's audit_event (invariant #8:
# anything unusual must be recorded) is never rolled back along with the
# failure it's documenting. A gap or mismatch that leaves no trace would be
# worse than not checking at all.
module Sync
  class OfflineInvoiceIngest
    ContiguityGap = Class.new(StandardError)
    TaxMismatch = Class.new(StandardError)
    AuthorityMismatch = Class.new(StandardError)

    def self.call(shop:, device:, grant:, records:, current_user: nil)
      new(shop: shop, device: device, grant: grant, records: records, current_user: current_user).call
    end

    def initialize(shop:, device:, grant:, records:, current_user: nil)
      @shop = shop
      @device = device
      @grant = grant
      @records = records.sort_by { |record| record.fetch("sequence") }
      @current_user = current_user
    end

    def call
      verify_authority!
      validated = @records.map { |record| validate!(record) }

      results = []
      @shop.with_lock do
        validated.each { |entry| results << write_one(entry) }
        # @current_user may be nil on a cold-started device that never
        # actually signed in this session (attribution came entirely from
        # per-record acting_user_id) — fall back to the last validated
        # entry's acting_user so the release! audit_event still has a real
        # actor, per invariant #8, rather than crashing on a nil.
        InvoiceAuthority.release!(@grant, user: @current_user || validated.last&.fetch(:acting_user))
      end
      results
    end

    private

    def verify_authority!
      raise AuthorityMismatch, "grant does not belong to this device" unless @grant.device_id == @device.id
      raise AuthorityMismatch, "grant already released" if @grant.released_at.present?
    end

    # Runs the contiguity and tax checks against current DB state and
    # returns everything write_one needs — no writes happen here, so a
    # raised error needs no rollback-surviving side channel for its
    # audit_event; it's written plainly, right where the check fails.
    #
    # Resolving the table session and acting user here (not in write_one)
    # is deliberate: a NoTakeawayCounter or ActingUser::Unresolved failure
    # must surface as cleanly as a gap or tax mismatch, before anything is
    # written, not partway through the locked write transaction.
    def validate!(record)
      expected_sequence = running_sequence
      reported_sequence = record.fetch("sequence")

      if reported_sequence != expected_sequence
        AuditEvent.record!(
          action: "offline_invoice_gap", subject: @grant, device: @device, user: @current_user,
          payload: { expected_sequence: expected_sequence, reported_sequence: reported_sequence }
        )
        raise ContiguityGap, "expected sequence #{expected_sequence}, got #{reported_sequence}"
      end
      @running_sequence = reported_sequence

      acting_user = Sync::ActingUser.resolve!(shop: @shop, current_user: @current_user, payload: record)
      table_session = resolve_table_session(record, acting_user)

      taxable_paise = record.fetch("items").sum { |item| menu_item_price(item) * item.fetch("quantity") }
      computed = Billing.compute(shop: @shop, taxable_paise: taxable_paise)
      reported_total = record.fetch("total_paise")

      if computed.total_paise != reported_total
        AuditEvent.record!(
          action: "offline_invoice_tax_mismatch", subject: @grant, device: @device, user: acting_user,
          payload: { computed_total_paise: computed.total_paise, reported_total_paise: reported_total }
        )
        raise TaxMismatch, "computed #{computed.total_paise}, device reported #{reported_total}"
      end

      { record: record, table_session: table_session, acting_user: acting_user, sequence: reported_sequence, computed: computed }
    end

    def resolve_table_session(record, acting_user)
      if record["client_session_token"]
        TableSession.resolve_for_takeaway!(
          shop: @shop, client_session_token: record.fetch("client_session_token"), opened_by: acting_user
        )
      else
        @shop.table_sessions.find(record.fetch("table_session_id"))
      end
    end

    def running_sequence
      @running_sequence ||= @grant.last_reported_sequence || @grant.granted_sequence
      @running_sequence + 1
    end

    def menu_item_price(item)
      MenuItem.find(item.fetch("menu_item_id")).price_paise
    end

    def write_one(entry)
      record = entry.fetch(:record)
      table_session = entry.fetch(:table_session)
      acting_user = entry.fetch(:acting_user)
      items_attributes = record.fetch("items").map do |item|
        { menu_item_id: item.fetch("menu_item_id"), quantity: item.fetch("quantity") }
      end
      client_token = record.fetch("client_token", record.fetch("id"))

      Ticket.submit!(
        table_session: table_session, client_token: client_token,
        placed_by: acting_user, items_attributes: items_attributes
      )

      Current.ingesting_invoice_authority = true
      invoice = Billing.record_payment_and_settle!(
        table_session: table_session,
        method: record.fetch("method"),
        amount_paise: entry.fetch(:computed).total_paise,
        received_by: acting_user,
        client_token: client_token,
        already_printed_at: record.fetch("issued_at", Time.current.iso8601)
      )
      Current.ingesting_invoice_authority = false

      @grant.update!(last_reported_sequence: entry.fetch(:sequence))

      { client_action_id: record.fetch("id"), invoice_number: invoice&.number }
    ensure
      Current.ingesting_invoice_authority = false
    end
  end
end
