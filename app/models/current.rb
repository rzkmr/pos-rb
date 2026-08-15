class Current < ActiveSupport::CurrentAttributes
  attribute :shop, :device, :user, :admin

  # Set only by Sync::OfflineInvoiceIngest while replaying a device's
  # already-issued offline invoices back into real Invoice rows — the one
  # legitimate case where Billing.issue_invoice! must proceed even though
  # an InvoiceAuthorityGrant is live for this shop. See
  # Billing.issue_invoice!'s guard and InvoiceAuthority.ingesting?.
  attribute :ingesting_invoice_authority
end
