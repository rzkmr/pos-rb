require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "pair! returns a device and a plaintext token that authenticates" do
    device, token = Device.pair!(shop: shops(:alpha), label: "Kitchen")

    assert device.persisted?
    assert device.authenticate_token(token)
    assert_not device.authenticate_token("wrong")
  end
end
