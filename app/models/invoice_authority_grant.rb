# Records one device holding sole authority to issue invoice numbers for
# a shop while offline. See InvoiceAuthority for the lifecycle and
# Billing.issue_invoice!'s guard for where this is actually enforced —
# this model only stores the fact; it doesn't decide anything on its own.
class InvoiceAuthorityGrant < ApplicationRecord
  include ShopScoped

  belongs_to :device

  validates :financial_year, presence: true
  validates :granted_sequence, presence: true
  validates :granted_at, presence: true
  validates :expires_at, presence: true

  scope :live, -> { where(released_at: nil) }
end
