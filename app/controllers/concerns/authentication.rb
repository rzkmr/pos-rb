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
    around_action :with_locale
  end

  private

  # Staff and admin each carry their own saved language preference. Before
  # sign-in (e.g. the login screen's own locale toggle) there's no actor to
  # persist a preference on yet, so LocalesController falls back to
  # session[:locale] for that request. Reset after each request — Rails
  # reuses threads, so I18n.locale must not leak.
  def with_locale(&block)
    I18n.with_locale(Current.user&.locale || Current.admin&.locale || session[:locale] || I18n.default_locale, &block)
  end

  # No shop exists yet on a fresh install — send every request to the
  # one-time setup wizard instead of "Device not paired". See SetupController.
  def redirect_to_setup_if_needed
    return if Shop.exists?

    redirect_to new_setup_path unless is_a?(SetupController)
  end

  # A device's own cookie already identifies exactly one shop (a device
  # belongs to one shop, ShopScoped) — deriving Current.shop from it, the
  # same way Api::V1::BaseController derives it from a device's bearer
  # token, is what makes cross-shop auth actually impossible rather than
  # merely unlikely with today's single production shop (CLAUDE.md;
  # ARCHITECTURE.md §14 is the eventual multi-shop story this keeps
  # correct ahead of). Falls back to Shop.order(:id).first only when
  # there's no device cookie to resolve from at all — the admin web
  # login path (set_current_admin, below) never carries one; admin auth
  # is username+password, independent of device pairing by design.
  def set_current_shop
    Current.shop = authenticated_device&.shop || Shop.order(:id).first
  end

  def set_current_device
    return unless authenticated_device

    Current.device = authenticated_device
    authenticated_device.touch_last_seen!
  end

  # Memoized so a request with a device cookie only pays the bcrypt-scan
  # cost once, even though both set_current_shop (which needs to know the
  # shop before it exists) and set_current_device (which needs the same
  # device) each call this.
  #
  # Iterates every device across every shop rather than scoping to a shop
  # first, because which shop it's in is exactly what authenticating this
  # token tells us — see Api::V1::BaseController#authenticate_device! for
  # the identical reasoning on the token-authenticated API side.
  #
  # ponytail: O(n) bcrypt compares across all devices in the deployment.
  # Same ceiling and same upgrade path noted on the API-side version of
  # this.
  def authenticated_device
    return @authenticated_device if defined?(@authenticated_device)

    token = cookies.signed[DEVICE_COOKIE]
    @authenticated_device = token && Device.unscoped.find { |d| d.authenticate_token(token) }
  end

  # A shared-tablet PIN session is scoped to the device it was created on
  # (session[:device_id], set at sign-in — SessionsController#create).
  # Without this, a session cookie is only as safe as whichever OTHER
  # device on the shop happens to be reachable — copy the session
  # cookie to a second paired tablet and the same signed-in user carries
  # over with no PIN re-entry, since session[:user_id] alone never
  # proved anything about which physical device was making the request.
  def set_current_user
    user_id = session[:user_id]
    return unless user_id
    return unless session[:device_id] && Current.device && session[:device_id] == Current.device.id

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
