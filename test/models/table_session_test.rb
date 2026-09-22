require "test_helper"

class TableSessionTest < ActiveSupport::TestCase
  setup { Current.shop = shops(:alpha) }
  teardown { Current.reset }

  test "resolve_for_takeaway! creates a session against the shop's takeaway counter" do
    shop = shops(:alpha)
    counter = shop.dining_tables.create!(label: "Takeaway", seats: 1, takeaway: true)
    token = SecureRandom.uuid

    session = TableSession.resolve_for_takeaway!(shop: shop, client_session_token: token, opened_by: users(:alpha_waiter))

    assert_equal counter, session.dining_table
    assert_equal token, session.client_session_token
  end

  test "resolve_for_takeaway! returns the same session for the same token, not a duplicate" do
    shop = shops(:alpha)
    shop.dining_tables.create!(label: "Takeaway", seats: 1, takeaway: true)
    token = SecureRandom.uuid

    first = TableSession.resolve_for_takeaway!(shop: shop, client_session_token: token, opened_by: users(:alpha_waiter))

    assert_no_difference "TableSession.count" do
      second = TableSession.resolve_for_takeaway!(shop: shop, client_session_token: token, opened_by: users(:alpha_waiter))
      assert_equal first, second
    end
  end

  test "resolve_for_takeaway! raises when the shop has no takeaway counter" do
    shop = shops(:alpha)
    shop.dining_tables.update_all(takeaway: false)

    assert_raises(TableSession::NoTakeawayCounter) do
      TableSession.resolve_for_takeaway!(shop: shop, client_session_token: SecureRandom.uuid, opened_by: users(:alpha_waiter))
    end
  end
end
