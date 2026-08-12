class DiningTable < ApplicationRecord
  include ShopScoped

  has_many :table_sessions, dependent: :restrict_with_error

  validates :label, presence: true, uniqueness: { scope: :shop_id }
  validates :seats, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:position) }

  def open_session
    table_sessions.open.order(opened_at: :desc).first
  end
end
