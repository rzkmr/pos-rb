require "test_helper"

class ClientActionTest < ActiveSupport::TestCase
  setup { Current.shop = shops(:alpha) }
  teardown { Current.reset }

  test "client_action_id is unique per shop" do
    shop = shops(:alpha)
    ClientAction.create!(shop: shop, client_action_id: "dup-1", kind: "void_ticket_item", status: "applied", applied_at: Time.current)

    duplicate = ClientAction.new(shop: shop, client_action_id: "dup-1", kind: "void_ticket_item", status: "applied", applied_at: Time.current)

    assert_not duplicate.valid?
  end

  test "the same client_action_id is allowed across different shops" do
    ClientAction.create!(shop: shops(:alpha), client_action_id: "shared-id", kind: "void_ticket_item", status: "applied", applied_at: Time.current)

    other_shop_action = ClientAction.new(shop: shops(:beta), client_action_id: "shared-id", kind: "void_ticket_item", status: "applied", applied_at: Time.current)

    assert other_shop_action.valid?
  end
end
