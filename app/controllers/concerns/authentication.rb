module Authentication
  extend ActiveSupport::Concern

  DEVICE_COOKIE = :device_token

  included do
    before_action :set_current_shop
    before_action :set_current_device
    before_action :set_current_user
    before_action :require_device
    before_action :require_user
  end

  private

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

  def require_device
    return if Current.device

    render plain: "Device not paired", status: :unauthorized
  end

  def require_user
    return if Current.user

    redirect_to new_session_path
  end
end
