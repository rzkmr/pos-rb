# Pure liveness ping — no data, no auth requirement. Used by the kitchen
# display's staleness check and by connectivity_controller.js (mounted on
# every signed-in screen, staff and admin alike) to detect a dead LAN
# without conflating it with device-pairing or session state.
class HeartbeatsController < ApplicationController
  skip_before_action :redirect_to_setup_if_needed
  skip_before_action :require_device
  skip_before_action :require_user

  def show
    head :ok
  end
end
