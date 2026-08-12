module Authentication
  extend ActiveSupport::Concern

  DEVICE_COOKIE = :device_token

  included do
    before_action :redirect_to_setup_if_needed
    before_action :set_current_shop
    before_action :set_current_admin
    before_action :set_current_device
    before_action :set_current_user
    before_action :require_device
    before_action :require_user
  end

  private

  # No shop exists yet on a fresh install — send every request to the
  # one-time setup wizard instead of "Device not paired". See SetupController.
  def redirect_to_setup_if_needed
    return if Shop.exists?

    redirect_to new_setup_path unless is_a?(SetupController)
  end

  # Single shop in production; see CLAUDE.md — multi-tenancy is a later routing change.
  def set_current_shop
    Current.shop = Shop.first
  end

  def set_current_device
    token = cookies.signed[DEVICE_COOKIE]
    return unless token

    device = Current.shop&.devices&.find { |d| d.authenticate_token(token) }
    return unless device

    Current.device = device
    device.touch_last_seen!
  end

  def set_current_user
    user_id = session[:user_id]
    return unless user_id

    Current.user = Current.shop&.users&.active&.find_by(id: user_id)
  end

  def set_current_admin
    admin_user_id = session[:admin_user_id]
    return unless admin_user_id

    Current.admin = Current.shop&.admin_users&.active&.find_by(id: admin_user_id)
  end

  def require_device
    return if Current.device

    render "devices/not_paired", status: :unauthorized, layout: true
  end

  def require_user
    return if Current.user

    redirect_to new_session_path
  end
end
