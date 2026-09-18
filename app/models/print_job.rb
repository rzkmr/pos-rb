class PrintJob < ApplicationRecord
  include ShopScoped
  include BikramSambatDated

  bs_dates_for :created_at

  KINDS = %w[invoice kot duplicate].freeze
  STATUSES = %w[queued sent failed].freeze

  belongs_to :invoice

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :attempts, numericality: { greater_than_or_equal_to: 0 }

  scope :failed, -> { where(status: "failed") }
end
