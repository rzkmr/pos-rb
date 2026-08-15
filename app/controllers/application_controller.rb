class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Billing::InvoiceAuthorityHeld, with: :invoice_authority_held

  private

  # A cashier hitting this mid-service must never see a stack trace or a
  # generic error — CLAUDE.md invariant #9's spirit applied to billing, not
  # just the kitchen display.
  def invoice_authority_held(exception)
    grant = exception.grant
    flash.now[:alert] = t("shared.invoice_authority_held", device: grant.device.label, since: l(grant.granted_at, format: :short))
    render "shared/invoice_authority_held", status: :conflict, layout: true
  end
end
