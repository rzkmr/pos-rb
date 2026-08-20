class DiningTable < ApplicationRecord
  include ShopScoped
  include ApiSyncEmitting

  has_many :table_sessions, dependent: :restrict_with_error
  has_many :held_carts, dependent: :destroy

  validates :label, presence: true, uniqueness: { scope: :shop_id }
  validates :seats, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:position) }
  scope :takeaway_counters, -> { where(takeaway: true) }

  def open_session
    table_sessions.open.order(opened_at: :desc).first
  end

  private

  def api_sync_record
    { id: id, label: label, seats: seats, position: position, takeaway: takeaway }
  end
end
