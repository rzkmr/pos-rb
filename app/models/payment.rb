class Payment < ApplicationRecord
  include ShopScoped
  include BikramSambatDated

  bs_dates_for :created_at

  METHODS = %w[cash upi card other].freeze

  belongs_to :table_session
  belongs_to :received_by, class_name: "User"

  validates :method, inclusion: { in: METHODS }
  validates :amount_paise, numericality: { greater_than: 0 }
end
