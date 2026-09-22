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

  # Rupee value for /api/v1 consumers — that wire contract documents
  # gross_price_rupees as the field to build tax/total math on
  # (AGENT-API-GUIDE.md), so it's computed once here and shared by
  # every /api/v1 payload rather than each controller re-deriving it.
  # gross_price_paisa is still stored and is still what Billing.compute
  # and every other internal/server-side calculation uses without
  # exception — CLAUDE.md invariant #1 ("Money is integer paisa. Always")
  # governs the server's own arithmetic, not what the wire format leads
  # with; gross_price_paisa still rides along in every /api/v1 payload
  # for a client that wants exact integer math instead.
  def gross_price_rupees
    gross_price_paisa.to_i.fdiv(100).round(2)
  end

  private

  def api_sync_record
    { id: id, name: name, category: category,
      gross_price_rupees: gross_price_rupees, gross_price_paisa: gross_price_paisa,
      variants: variants, active: active, position: position }
  end
end
