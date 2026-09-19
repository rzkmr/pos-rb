class Payment < ApplicationRecord
  include ShopScoped
  include BikramSambatDated

  bs_dates_for :created_at

  # Nepal payment methods (CLAUDE.md) — not UPI, that's India.
  METHODS = %w[cash fonepay esewa khalti imepay card credit other].freeze

  belongs_to :table_session
  belongs_to :received_by, class_name: "User"

  validates :method, inclusion: { in: METHODS }
  validates :amount_paisa, numericality: { greater_than: 0 }
end
