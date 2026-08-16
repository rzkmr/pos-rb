require "test_helper"

class Sync::ActingUserTest < ActiveSupport::TestCase
  test "prefers current_user when present, ignoring any acting_user_id" do
    resolved = Sync::ActingUser.resolve!(shop: shops(:alpha), current_user: users(:alpha_waiter), payload: { "acting_user_id" => 999_999 })

    assert_equal users(:alpha_waiter), resolved
  end

  test "resolves acting_user_id when there is no current_user" do
    resolved = Sync::ActingUser.resolve!(shop: shops(:alpha), current_user: nil, payload: { "acting_user_id" => users(:alpha_waiter).id })

    assert_equal users(:alpha_waiter), resolved
  end

  test "raises when neither current_user nor acting_user_id is present" do
    assert_raises(Sync::ActingUser::Unresolved) do
      Sync::ActingUser.resolve!(shop: shops(:alpha), current_user: nil, payload: {})
    end
  end

  test "raises for an acting_user_id that doesn't belong to the shop" do
    assert_raises(Sync::ActingUser::Unresolved) do
      Sync::ActingUser.resolve!(shop: shops(:alpha), current_user: nil, payload: { "acting_user_id" => users(:alpha_waiter).id + 999_999 })
    end
  end

  test "raises for a deactivated user's acting_user_id" do
    users(:alpha_waiter).update!(active: false)

    assert_raises(Sync::ActingUser::Unresolved) do
      Sync::ActingUser.resolve!(shop: shops(:alpha), current_user: nil, payload: { "acting_user_id" => users(:alpha_waiter).id })
    end
  end
end
