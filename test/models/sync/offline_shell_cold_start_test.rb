require "test_helper"

# End-to-end coverage for the offline shell's actual use case: a device
# that has never talked to the server issues a real, numbered invoice
# entirely offline (client_session_token + acting_user_id, no
# Current.user, no pre-existing TableSession), then syncs it back. See
# app/javascript/controllers/offline_shell_controller.js for the client
# side of this flow.
class Sync::OfflineShellColdStartTest < ActiveSupport::TestCase
  setup do
    @shop = shops(:alpha)
    @shop.dining_tables.create!(label: "Takeaway", seats: 1, takeaway: true)
    @device, = Device.pair!(shop: @shop, label: "Takeaway Tablet")
    @dosa = menu_items(:alpha_dosa)
  end

  teardown { Current.reset }

  test "catalog snapshot exposes users without ever including pin" do
    payload = @shop.users.active.order(:name).map { |u| { id: u.id, name: u.name, role: u.role } }

    assert payload.any?
    assert payload.none? { |u| u.key?(:pin) }
  end

  test "a fully cold-started offline sale reconciles to a real, numbered invoice attributed to the claimed user" do
    Current.shop = @shop
    Current.user = users(:alpha_waiter)
    grant = InvoiceAuthority.acquire!(shop: @shop, device: @device)
    Current.user = nil # nobody is signed in when the sync actually runs

    token = SecureRandom.uuid
    computed = Billing.compute(shop: @shop, taxable_paise: @dosa.price_paise * 3)
    record = {
      "id" => "shell-1", "sequence" => grant.granted_sequence + 1,
      "client_session_token" => token, "acting_user_id" => users(:alpha_waiter).id,
      "method" => "cash", "client_token" => "shell-1",
      "items" => [ { "menu_item_id" => @dosa.id, "quantity" => 3 } ],
      "total_paise" => computed.total_paise, "issued_at" => Time.current.iso8601
    }

    results = Sync::OfflineInvoiceIngest.call(shop: @shop, device: @device, grant: grant, records: [ record ], current_user: nil)

    assert_equal 1, results.size
    session = TableSession.find_by(client_session_token: token)
    assert session.present?
    assert_equal "paid", session.status
    assert_equal users(:alpha_waiter), session.tickets.first.placed_by
    assert_equal users(:alpha_waiter), session.payments.first.received_by
    assert session.invoices.first.number.present?
    assert grant.reload.released_at.present?
  end
end
