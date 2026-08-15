# The takeaway counter device requests/releases offline invoice authority
# through here. See InvoiceAuthority for the lifecycle and
# Billing.issue_invoice!'s guard for where the lock is actually enforced —
# this controller is just the HTTP surface over that.
class Sync::InvoiceAuthorityController < ApplicationController
  def create
    grant = InvoiceAuthority.acquire!(shop: Current.shop, device: Current.device)
    render json: serialize(grant), status: :created
  rescue InvoiceAuthority::AlreadyGranted
    render json: { error: "invoice authority is already held" }, status: :conflict
  end

  def destroy
    grant = Current.shop.invoice_authority_grants.live.find_by(device: Current.device)
    return head :no_content unless grant

    InvoiceAuthority.release!(grant)
    head :no_content
  end

  private

  def serialize(grant)
    {
      id: grant.id,
      financial_year: grant.financial_year,
      granted_sequence: grant.granted_sequence,
      expires_at: grant.expires_at.iso8601
    }
  end
end
