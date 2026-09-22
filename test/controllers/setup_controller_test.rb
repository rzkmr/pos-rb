require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  # SetupController's whole premise ("no shop exists yet") can't be
  # exercised against the fixture set, which always seeds shops — so
  # these tests actually clear every shop row for their duration inside
  # a transaction that rolls back after, rather than stubbing
  # Shop.exists? (Minitest 6 dropped Object#stub/mocking — see
  # minitest-6.0.6's own lib/minitest/, no mock.rb ships anymore).
  # Deleting for real, in a wrapped transaction, also exercises the
  # actual `redirect_to_setup_if_needed` / `ensure_not_already_set_up`
  # code paths end to end instead of a stubbed return value.
  def without_any_shop(&block)
    ActiveRecord::Base.transaction do
      Shop.delete_all
      block.call
      raise ActiveRecord::Rollback
    end
  end

  test "any request redirects to setup when no shop exists" do
    without_any_shop do
      get dining_tables_url
      assert_redirected_to new_setup_path
    end
  end

  test "create bootstraps the shop and its first AdminUser, no device pairing" do
    without_any_shop do
      assert_difference [ "Shop.count", "AdminUser.count" ], 1 do
        assert_no_difference "Device.unscoped.count" do
          post setup_url, params: {
            name: "Bootstrap Shop",
            address: "1 Test Road",
            admin_pin: "9999",
            admin_username: "owner",
            admin_password: "supersecret1"
          }
        end
      end

      assert_redirected_to done_setup_path(username: "owner")
      assert_not cookies[:device_token].present?
    end
  end

  test "create rejects a non-4-digit pairing PIN" do
    without_any_shop do
      assert_no_difference "Shop.count" do
        post setup_url, params: {
          name: "Bootstrap Shop",
          admin_pin: "99",
          admin_username: "owner",
          admin_password: "supersecret1"
        }
      end

      assert_response :unprocessable_entity
    end
  end

  test "setup is unreachable once a shop already exists" do
    get new_setup_url

    assert_redirected_to root_path
  end
end
