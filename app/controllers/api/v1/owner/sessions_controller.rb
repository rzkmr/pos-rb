# Lets the Android app confirm an owner/admin credential before it shows
# the device-pairing screen — same AdminUser credential as the web
# Admin::SessionsController, but stateless: there is no server-side
# session on this API (Api::V1::BaseController), so this returns the
# owner's identity rather than setting a cookie. It issues no device
# token; pairing is a separate step (Api::V1::Devices::PairingsController)
# so a lost/misused owner credential cannot, on its own, mint a device.
#
# Deliberately does NOT inherit Api::V1::BaseController: there is no
# device token yet at this point in the flow.
class Api::V1::Owner::SessionsController < ActionController::API
  rate_limit to: 5, within: 15.minutes, by: -> { request.remote_ip },
             with: -> { render json: { error: "too_many_attempts" }, status: :too_many_requests }

  def create
    shop = Shop.order(:id).first
    return render json: { error: "no_shop_configured" }, status: :unprocessable_entity unless shop

    admin_user = shop.admin_users.active.find_by("lower(username) = ?", params[:username].to_s.downcase)

    if admin_user&.authenticate(params[:password])
      render json: { owner: { id: admin_user.id, username: admin_user.username } }
    else
      render json: { error: "invalid_credentials" }, status: :unauthorized
    end
  end
end
