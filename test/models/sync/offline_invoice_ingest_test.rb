require "test_helper"

class Sync::OfflineInvoiceIngestTest < ActiveSupport::TestCase
  setup do
    Current.shop = shops(:alpha)
    Current.user = users(:alpha_waiter)
    @device, = Device.pair!(shop: shops(:alpha), label: "Takeaway Tablet")
    @grant = InvoiceAuthority.acquire!(shop: shops(:alpha), device: @device)
    @counter = shops(:alpha).dining_tables.create!(label: "Takeaway", seats: 1, takeaway: true)
    @dosa = menu_items(:alpha_dosa)
  end

  teardown { Current.reset }

  def build_record(id:, sequence:, session:, total_paise: 12600)
    {
      "id" => id, "sequence" => sequence, "table_session_id" => session.id, "method" => "cash",
      "client_token" => id, "items" => [ { "menu_item_id" => @dosa.id, "quantity" => 1 } ],
      "total_paise" => total_paise, "issued_at" => Time.current.iso8601
    }
  end

  test "ingests a gapless batch, advances the shop counter, and releases the grant" do
    sessions = Array.new(2) { @counter.table_sessions.create!(opened_by: users(:alpha_waiter), opened_at: Time.current, status: "open") }
    records = sessions.each_with_index.map { |s, i| build_record(id: "off-#{i}", sequence: @grant.granted_sequence + i + 1, session: s) }

    results = Sync::OfflineInvoiceIngest.call(shop: shops(:alpha), device: @device, grant: @grant, records: records)

    assert_equal 2, results.size
    assert_equal 2, Invoice.where(id: sessions.map { |s| s.invoices.first&.id }.compact).count
    assert_equal @grant.granted_sequence + 2, shops(:alpha).reload.invoice_sequence
    assert @grant.reload.released_at.present?
  end

  test "a sequence gap is rejected, writes an audit_event, and creates nothing" do
    session = @counter.table_sessions.create!(opened_by: users(:alpha_waiter), opened_at: Time.current, status: "open")
    record = build_record(id: "gap-1", sequence: @grant.granted_sequence + 2, session: session)

    assert_no_difference "Invoice.count" do
      assert_raises(Sync::OfflineInvoiceIngest::ContiguityGap) do
        Sync::OfflineInvoiceIngest.call(shop: shops(:alpha), device: @device, grant: @grant, records: [ record ])
      end
    end

    assert AuditEvent.exists?(action: "offline_invoice_gap")
  end

  test "a tax mismatch is rejected, writes an audit_event, and creates nothing" do
    session = @counter.table_sessions.create!(opened_by: users(:alpha_waiter), opened_at: Time.current, status: "open")
    record = build_record(id: "tax-1", sequence: @grant.granted_sequence + 1, session: session, total_paise: 999_999)

    assert_no_difference "Invoice.count" do
      assert_raises(Sync::OfflineInvoiceIngest::TaxMismatch) do
        Sync::OfflineInvoiceIngest.call(shop: shops(:alpha), device: @device, grant: @grant, records: [ record ])
      end
    end

    assert AuditEvent.exists?(action: "offline_invoice_tax_mismatch")
  end

  test "a device other than the grant holder cannot ingest" do
    other_device, = Device.pair!(shop: shops(:alpha), label: "Impostor")
    session = @counter.table_sessions.create!(opened_by: users(:alpha_waiter), opened_at: Time.current, status: "open")
    record = build_record(id: "imp-1", sequence: @grant.granted_sequence + 1, session: session)

    assert_raises(Sync::OfflineInvoiceIngest::AuthorityMismatch) do
      Sync::OfflineInvoiceIngest.call(shop: shops(:alpha), device: other_device, grant: @grant, records: [ record ])
    end
  end

  test "re-ingesting after the grant was already released is refused" do
    session = @counter.table_sessions.create!(opened_by: users(:alpha_waiter), opened_at: Time.current, status: "open")
    record = build_record(id: "resync-1", sequence: @grant.granted_sequence + 1, session: session)

    Sync::OfflineInvoiceIngest.call(shop: shops(:alpha), device: @device, grant: @grant, records: [ record ])
    invoice_count = Invoice.count

    assert_raises(Sync::OfflineInvoiceIngest::AuthorityMismatch) do
      Sync::OfflineInvoiceIngest.call(shop: shops(:alpha), device: @device, grant: @grant.reload, records: [ record ])
    end
    assert_equal invoice_count, Invoice.count
  end
end
