class MenuItem < ApplicationRecord
  include ShopScoped
  include ApiSyncEmitting

  CATEGORIES = %w[main beverage side].freeze

  has_many :ticket_items, dependent: :restrict_with_error

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :price_paise, numericality: { greater_than_or_equal_to: 0 }
  validates :hsn_sac, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position) }

  private

  def api_sync_record
    { id: id, name: name, category: category, price_paise: price_paise, hsn_sac: hsn_sac,
      variants: variants, active: active, position: position }
  end
end
