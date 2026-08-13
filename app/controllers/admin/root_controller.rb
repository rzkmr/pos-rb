class Admin::RootController < Admin::BaseController
  def show
    @paired_device_count = Current.shop.devices.count
  end
end
