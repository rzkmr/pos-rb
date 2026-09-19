class Invoice < ApplicationRecord
  include ShopScoped
  include BikramSambatDated

  bs_dates_for :issued_at

  belongs_to :table_session

  has_many :print_jobs, dependent: :restrict_with_error

  validates :number, presence: true, uniqueness: true
  validates :financial_year, presence: true
  validates :sequence, presence: true, uniqueness: { scope: [ :shop_id, :financial_year ] }
  validates :issued_at, presence: true
  validates :base_paisa, :service_charge_paisa, :vat_paisa, :gross_paisa,
            numericality: { greater_than_or_equal_to: 0 }
  validates :print_count, numericality: { greater_than_or_equal_to: 0 }
end
