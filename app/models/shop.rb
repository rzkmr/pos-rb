class Shop < ApplicationRecord
  has_secure_password :admin_pin, validations: false

  has_many :users, dependent: :restrict_with_error
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
