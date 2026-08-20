# Unauthenticated — drives the client's connectivity indicator (API-SPEC.md
# §9). Deliberately does NOT inherit Api::V1::BaseController: a device
# with a revoked or not-yet-paired token must still be able to tell
# whether the server is reachable at all.
class Api::V1::HealthController < ActionController::API
  def show
    shop = Shop.order(:id).first
    render json: { ok: true, server_time: Time.current.iso8601, cursor: shop&.api_sync_cursor || 0 }
  end
end
