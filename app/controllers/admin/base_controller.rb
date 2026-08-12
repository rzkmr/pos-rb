# Admin screens authenticate via Admin::SessionsController's username +
# password login. They are independent of the device-pairing/PIN system
# that gates shop-floor screens — an admin does not need a paired device.
class Admin::BaseController < ApplicationController
  skip_before_action :set_current_device
  skip_before_action :set_current_user
  skip_before_action :require_device
  skip_before_action :require_user
  before_action :require_admin_login

  private

  def require_admin_login
    return if Current.admin

    redirect_to new_admin_session_path
  end
end
