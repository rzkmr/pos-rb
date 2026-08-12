require "test_helper"

class TableSessionsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:alpha_waiter), pin: "2222") }

  test "create opens a new session on a free table" do
    free_table = DiningTable.create!(shop: shops(:alpha), label: "T-Free", seats: 2)

    assert_difference "TableSession.count", 1 do
      post table_sessions_url(dining_table_id: free_table.id)
    end

    assert_redirected_to table_session_url(TableSession.order(:created_at).last)
  end

  test "create reuses the table's existing open session" do
    existing = table_sessions(:alpha_t1_open)

    assert_no_difference "TableSession.count" do
      post table_sessions_url(dining_table_id: existing.dining_table_id)
    end

    assert_redirected_to table_session_url(existing)
  end

  test "show renders the menu and existing tickets for the session" do
    get table_session_url(table_sessions(:alpha_t1_open))
    assert_response :success
  end
end
