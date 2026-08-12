require "test_helper"

class TicketTest < ActiveSupport::TestCase
  setup { Current.shop = shops(:alpha) }
  teardown { Current.reset }

  test "submit! with a duplicate client_token returns the existing ticket, never a new one" do
    session = TableSession.create!(
      dining_table: dining_tables(:alpha_t1),
      opened_by: users(:alpha_waiter),
      opened_at: Time.current
    )
    token = SecureRandom.uuid
    items = [ { menu_item: menu_items(:alpha_dosa), quantity: 2 } ]

    first = Ticket.submit!(table_session: session, client_token: token, placed_by: users(:alpha_waiter), items_attributes: items)
    second = Ticket.submit!(table_session: session, client_token: token, placed_by: users(:alpha_waiter), items_attributes: items)

    assert_equal first.id, second.id
    assert_equal 1, Ticket.where(client_token: token).count
  end

  test "submit! retry works inside an enclosing transaction without poisoning it" do
    session = TableSession.create!(
      dining_table: dining_tables(:alpha_t1),
      opened_by: users(:alpha_waiter),
      opened_at: Time.current
    )
    token = SecureRandom.uuid
    items = [ { menu_item: menu_items(:alpha_dosa), quantity: 1 } ]

    ActiveRecord::Base.transaction do
      first = Ticket.submit!(table_session: session, client_token: token, placed_by: users(:alpha_waiter), items_attributes: items)
      second = Ticket.submit!(table_session: session, client_token: token, placed_by: users(:alpha_waiter), items_attributes: items)
      assert_equal first.id, second.id

      # A query after the retry must still work — this is what a bare
      # `rescue ActiveRecord::RecordNotUnique` without a savepoint breaks.
      assert_equal 1, session.tickets.count
    end
  end
end
