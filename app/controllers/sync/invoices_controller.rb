# Ingests the offline-issued invoice ledger from the takeaway counter once
# it's back online (see lib/offline_invoice.js, InvoiceAuthority,
# Sync::OfflineInvoiceIngest). Deliberately a separate endpoint from
# Sync::ActionsController — this is not a generic queued action, it's the
# one operation that turns client-side-only invoices into real,
# server-persisted Invoice rows and releases the authority grant.
class Sync::InvoicesController < ApplicationController
  def create
    grant = Current.shop.invoice_authority_grants.live.find_by(device: Current.device)
    return render json: { error: "no live grant for this device" }, status: :unprocessable_entity unless grant

    results = Sync::OfflineInvoiceIngest.call(
      shop: Current.shop, device: Current.device, grant: grant, records: records_params
    )

    render json: { results: results }
  rescue Sync::OfflineInvoiceIngest::ContiguityGap, Sync::OfflineInvoiceIngest::TaxMismatch, Sync::OfflineInvoiceIngest::AuthorityMismatch => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  # permit! is deliberate: a record's shape (items is a variable-length
  # array of hashes) doesn't fit strong params' declarative style well, and
  # every value here is read individually via Hash#fetch in
  # Sync::OfflineInvoiceIngest rather than mass-assigned into an
  # ActiveRecord model — so there's no injection surface being opened.
  # This endpoint also requires full device+user auth already.
  def records_params
    params.require(:records).map { |record| record.permit!.to_h }
  end
end
