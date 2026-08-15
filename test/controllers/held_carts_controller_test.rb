require "test_helper"

class HeldCartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alpha_waiter), pin: "2222")
    @counter = shops(:alpha).dining_tables.create!(label: "Takeaway", seats: 1, takeaway: true)
  end

  test "holding a cart creates a HeldCart without touching tickets or payments" do
    assert_no_difference [ "Ticket.count", "Payment.count" ] do
      assert_difference "HeldCart.count", 1 do
        post dining_table_held_carts_url(@counter), params: {
          items: [ { menu_item_id: menu_items(:alpha_dosa).id, name_snapshot: "Masala Dosa", unit_price_paise: 12000, quantity: 2 } ]
        }, as: :json
      end
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal 2, body["item_count"]
    assert_equal 24000, body["total_paise"]
  end

  test "index lists held carts for the counter, scoped to the shop" do
    held = @counter.held_carts.create!(
      items: [ { menu_item_id: menu_items(:alpha_dosa).id, name_snapshot: "Masala Dosa", unit_price_paise: 12000, quantity: 1 } ],
      held_by: users(:alpha_waiter),
      held_at: Time.current
    )

    get dining_table_held_carts_url(@counter), as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ held.id ], body.map { |c| c["id"] }
  end

  test "destroy removes the held cart" do
    held = @counter.held_carts.create!(
      items: [ { menu_item_id: menu_items(:alpha_dosa).id, name_snapshot: "Masala Dosa", unit_price_paise: 12000, quantity: 1 } ],
      held_by: users(:alpha_waiter),
      held_at: Time.current
    )

    assert_difference "HeldCart.count", -1 do
      delete held_cart_url(held)
    end

    assert_response :no_content
  end
end
