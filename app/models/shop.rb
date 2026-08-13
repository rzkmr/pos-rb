class Shop < ApplicationRecord
  # A shared operational PIN handed out verbally by admin to staff pairing
  # a new device — same trust model as a WiFi password, not a personal
  # credential. Stored in the clear so admin can look it up and read it
  # off any time from Settings; see the migration for why hashing it made
  # the actual "how does staff learn this PIN" question unanswerable.
  validates :pairing_pin, format: { with: /\A\d{4}\z/, message: "must be exactly 4 digits" }, allow_nil: true

  has_many :users, dependent: :restrict_with_error
  has_many :admin_users, dependent: :restrict_with_error
  has_many :devices, dependent: :restrict_with_error
  has_many :dining_tables, dependent: :restrict_with_error
  has_many :table_sessions, dependent: :restrict_with_error
  has_many :menu_items, dependent: :restrict_with_error
  has_many :tickets, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :print_jobs, dependent: :restrict_with_error
  has_many :audit_events, dependent: :restrict_with_error

  validates :name, presence: true
  validates :state_code, presence: true
  validates :invoice_prefix, presence: true
  validates :invoice_fy, presence: true
  validates :gst_rate_bp, numericality: { greater_than_or_equal_to: 0 }
  validates :invoice_sequence, numericality: { greater_than_or_equal_to: 0 }

  def authenticate_pairing_pin(candidate)
    pairing_pin.present? && ActiveSupport::SecurityUtils.secure_compare(pairing_pin, candidate.to_s)
  end

  # India's financial year runs 1 April to 31 March.
  def self.financial_year_for(date)
    date.month >= 4 ? "#{date.year}-#{(date.year + 1) % 100}" : "#{date.year - 1}-#{date.year % 100}"
  end

  # Row-locks the shop and increments the gapless per-FY invoice counter.
  # Must be called inside the invoice-creating transaction.
  def next_invoice_sequence!(financial_year)
    reload_invoice_fy_if_rolled_over!(financial_year)
    increment!(:invoice_sequence)
    invoice_sequence
  end

  private

  def reload_invoice_fy_if_rolled_over!(financial_year)
    return if invoice_fy == financial_year

    update!(invoice_fy: financial_year, invoice_sequence: 0)
  end
end
