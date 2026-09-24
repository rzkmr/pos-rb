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

  test "resolve! finds by real integer id when the value is all digits" do
    session = table_sessions(:alpha_t1_open)

    found = TableSession.resolve!(shop: shops(:alpha), table_session_id: session.id)

    assert_equal session, found
  end

  test "resolve! finds by client_session_token when the value isn't a plain integer" do
    session = table_sessions(:alpha_t1_open)
    session.update!(client_session_token: SecureRandom.uuid)

    found = TableSession.resolve!(shop: shops(:alpha), table_session_id: session.client_session_token)

    assert_equal session, found
  end

  test "resolve! raises RecordNotFound (not nil) for an unknown id or token" do
    assert_raises(ActiveRecord::RecordNotFound) do
      TableSession.resolve!(shop: shops(:alpha), table_session_id: 999_999)
    end

    assert_raises(ActiveRecord::RecordNotFound) do
      TableSession.resolve!(shop: shops(:alpha), table_session_id: SecureRandom.uuid)
    end
  end

  test "resolve_or_open! creates a new session against the given dining_table on first call" do
    shop = shops(:alpha)
    table = shop.dining_tables.create!(label: "T9", seats: 4)
    token = SecureRandom.uuid

    session = TableSession.resolve_or_open!(shop: shop, dining_table: table, client_session_token: token, opened_by: users(:alpha_waiter))

    assert_equal table, session.dining_table
    assert_equal token, session.client_session_token
    assert_equal "open", session.status
  end

  test "resolve_or_open! returns the same session for a repeated client_session_token" do
    shop = shops(:alpha)
    table = shop.dining_tables.create!(label: "T9", seats: 4)
    token = SecureRandom.uuid

    first = TableSession.resolve_or_open!(shop: shop, dining_table: table, client_session_token: token, opened_by: users(:alpha_waiter))

    assert_no_difference "TableSession.count" do
      second = TableSession.resolve_or_open!(shop: shop, dining_table: table, client_session_token: token, opened_by: users(:alpha_waiter))
      assert_equal first, second
    end
  end

  test "resolve_or_open! joins a table's already-open session instead of creating a second one, even with a new client_session_token" do
    shop = shops(:alpha)
    table = shop.dining_tables.create!(label: "T9", seats: 4)
    first = TableSession.resolve_or_open!(shop: shop, dining_table: table, client_session_token: SecureRandom.uuid, opened_by: users(:alpha_waiter))

    assert_no_difference "TableSession.count" do
      second = TableSession.resolve_or_open!(shop: shop, dining_table: table, client_session_token: SecureRandom.uuid, opened_by: users(:alpha_waiter))
      assert_equal first, second
    end
  end
end
