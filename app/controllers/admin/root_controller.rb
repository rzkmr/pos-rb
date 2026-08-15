class Admin::RootController < Admin::BaseController
  def show
    @paired_device_count = Current.shop.devices.count
    @invoice_authority_held = InvoiceAuthority.live_for(Current.shop).present?
  end
end
