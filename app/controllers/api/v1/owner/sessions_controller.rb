# Lets the Android app authenticate an owner/admin credential and obtain a
# long-lived owner_session_token (API-SPEC.md §1a) — same AdminUser
# credential as the web Admin::SessionsController, but the API has no
# cookie to set, so the token travels in the response body instead and the
# client caches it (mirroring how a device token behaves post-pairing).
# It issues no device token; pairing is a separate step
# (Api::V1::Devices::PairingsController) so a lost/misused owner
# credential cannot, on its own, mint a device.
#
# Deliberately does NOT inherit Api::V1::BaseController: there is no
# device token yet at this point in the flow, and #destroy authenticates
# via the owner token itself, not a device token.
class Api::V1::Owner::SessionsController < ActionController::API
  rate_limit to: 5, within: 15.minutes, by: -> { request.remote_ip },
             with: -> { render json: { error: "too_many_attempts" }, status: :too_many_requests }

  before_action :set_shop
  before_action :authenticate_owner_session!, only: :destroy

  def create
    admin_user = @shop.admin_users.active.find_by("lower(username) = ?", params[:username].to_s.downcase)

    if admin_user&.authenticate(params[:password])
      _session, token = OwnerSession.issue!(admin_user: admin_user)
      render json: {
        owner_session_token: token,
        owner: { id: admin_user.id, username: admin_user.username },
        shop_id: @shop.id
      }
    else
      render json: { error: "invalid_credentials" }, status: :unauthorized
    end
  end

  def destroy
    @owner_session.destroy!
    head :no_content
  end

  private

  def set_shop
    @shop = Shop.order(:id).first
    render json: { error: "no_shop_configured" }, status: :unprocessable_entity unless @shop
  end

  def authenticate_owner_session!
    return unless @shop

    token = bearer_token
    return render json: { error: "missing bearer token" }, status: :unauthorized unless token

    session = @shop.owner_sessions.find { |s| s.authenticate_token(token) }
    return render json: { error: "invalid or revoked owner session" }, status: :unauthorized unless session

    @owner_session = session
    session.touch_last_used!
  end

  def bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")

    header.delete_prefix("Bearer ").strip.presence
  end
end
