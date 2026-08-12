class TableSession < ApplicationRecord
  include ShopScoped

  STATUSES = %w[open billed paid closed].freeze

  belongs_to :dining_table
  belongs_to :opened_by, class_name: "User"
  belongs_to :discount_approved_by, class_name: "User", optional: true

  has_many :tickets, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :opened_at, presence: true
  validates :discount_paise, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_reason, presence: true, if: -> { discount_paise.to_i > 0 }

  scope :open, -> { where(status: "open") }

  def subtotal_paise
    TicketItem.active.where(ticket: tickets).sum("quantity * unit_price_paise") - discount_paise.to_i
  end

  def paid_paise
    payments.sum(:amount_paise)
  end

  def apply_discount!(amount_paise:, reason:, approved_by:)
    update!(discount_paise: amount_paise, discount_reason: reason, discount_approved_by: approved_by)
  end
end
