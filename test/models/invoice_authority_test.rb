require "test_helper"

class InvoiceAuthorityTest < ActiveSupport::TestCase
  setup do
    Current.shop = shops(:alpha)
    Current.user = users(:alpha_waiter)
  end

  teardown { Current.reset }

  test "acquire! grants authority and blocks a second grant while it's live" do
    device, = Device.pair!(shop: shops(:alpha), label: "Takeaway Tablet")

    grant = InvoiceAuthority.acquire!(shop: shops(:alpha), device: device)

    assert grant.persisted?
    assert_nil grant.released_at

    other_device, = Device.pair!(shop: shops(:alpha), label: "Other device")
    assert_raises(InvoiceAuthority::AlreadyGranted) do
      InvoiceAuthority.acquire!(shop: shops(:alpha), device: other_device)
    end
  end

  test "release! frees the shop for a new grant" do
    device, = Device.pair!(shop: shops(:alpha), label: "Takeaway Tablet")
    grant = InvoiceAuthority.acquire!(shop: shops(:alpha), device: device)

    InvoiceAuthority.release!(grant)

    assert grant.reload.released_at.present?
    assert_nothing_raised { InvoiceAuthority.acquire!(shop: shops(:alpha), device: device) }
  end

  test "Billing.issue_invoice! raises for every other path while a grant is live" do
    device, = Device.pair!(shop: shops(:alpha), label: "Takeaway Tablet")
    InvoiceAuthority.acquire!(shop: shops(:alpha), device: device)

    session = table_sessions(:alpha_t1_open)
    dosa = menu_items(:alpha_dosa)
    Ticket.submit!(table_session: session, client_token: SecureRandom.uuid, placed_by: users(:alpha_waiter),
                    items_attributes: [ { menu_item_id: dosa.id, quantity: 1 } ])

    assert_no_difference "Invoice.count" do
      assert_raises(Billing::InvoiceAuthorityHeld) do
        Billing.record_payment_and_settle!(
          table_session: session, method: "cash",
          amount_paisa: Billing.compute(shop: shops(:alpha), gross_paisa: session.reload.subtotal_paisa).gross_paisa,
          received_by: users(:alpha_waiter)
        )
      end
    end
  end

  test "billing works normally once no grant is held" do
    session = table_sessions(:alpha_t1_open)
    dosa = menu_items(:alpha_dosa)
    Ticket.submit!(table_session: session, client_token: SecureRandom.uuid, placed_by: users(:alpha_waiter),
                    items_attributes: [ { menu_item_id: dosa.id, quantity: 1 } ])

    assert_difference "Invoice.count", 1 do
      Billing.record_payment_and_settle!(
        table_session: session, method: "cash",
        amount_paisa: Billing.compute(shop: shops(:alpha), gross_paisa: session.reload.subtotal_paisa).gross_paisa,
        received_by: users(:alpha_waiter)
      )
    end
  end
end
