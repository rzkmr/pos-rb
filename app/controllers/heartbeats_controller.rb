# Pure liveness ping — no data, no auth requirement. Used by the kitchen
# display's staleness check and by connectivity_controller.js (mounted on
# every signed-in screen, staff and admin alike) to detect a dead LAN
# without conflating it with device-pairing or session state.
#
# Also extends this device's live InvoiceAuthority grant, if it holds one
# (see InvoiceAuthority.heartbeat!) — piggybacked on the existing poll
# rather than a separate request, since a device that's still reachable
# here is, by definition, still online and doesn't need to have grabbed
# authority to issue offline in the first place. The grant only matters
# once THIS poll starts failing.
class HeartbeatsController < ApplicationController
  skip_before_action :redirect_to_setup_if_needed
  skip_before_action :require_device
  skip_before_action :require_user

  def show
    grant = Current.shop && Current.device ? InvoiceAuthority.live_for(Current.shop) : nil
    InvoiceAuthority.heartbeat!(grant) if grant && grant.device_id == Current.device.id

    head :ok
  end
end
