# Admin's only window into the offline-invoicing scheme: who holds the
# grant, since when, and an escape hatch if the holding device is lost or
# bricked and will never come back to release it itself.
class Admin::InvoiceAuthorityGrantsController < Admin::BaseController
  def index
    @grants = Current.shop.invoice_authority_grants.order(created_at: :desc).limit(50)
    @live_grant = @grants.find { |grant| grant.released_at.nil? }
  end

  def force_release
    grant = Current.shop.invoice_authority_grants.find(params[:id])
    reason = params.require(:reason)

    InvoiceAuthority.force_release!(grant, admin: Current.admin, reason: reason)

    redirect_to admin_invoice_authority_grants_path, notice: "Invoice authority released"
  end
end
