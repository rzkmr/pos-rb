class MenuItem < ApplicationRecord
  include ShopScoped
  include ApiSyncEmitting

  CATEGORIES = %w[main beverage side].freeze

  has_many :ticket_items, dependent: :restrict_with_error

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  # Gross, tax-inclusive — what the guest pays. Never store net and
  # multiply up (CLAUDE.md invariant #2).
  validates :gross_price_paisa, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position) }

  # Display-only rupee value alongside gross_price_paisa in API payloads —
  # paisa stays the field clients do arithmetic on (CLAUDE.md invariant
  # #1); this is for a consumer that just wants to show a price.
  def gross_price_rupees
    gross_price_paisa.to_i.fdiv(100).round(2)
  end

  private

  def api_sync_record
    { id: id, name: name, category: category,
      gross_price_paisa: gross_price_paisa, gross_price_rupees: gross_price_rupees,
      variants: variants, active: active, position: position }
  end
end
