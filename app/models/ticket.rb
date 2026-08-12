class Ticket < ApplicationRecord
  include ShopScoped

  STATUSES = %w[pending preparing ready served].freeze

  belongs_to :table_session
  belongs_to :placed_by, class_name: "User"

  has_many :ticket_items, dependent: :restrict_with_error
  accepts_nested_attributes_for :ticket_items

  validates :client_token, presence: true, uniqueness: true
  validates :number, presence: true
  validates :placed_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  broadcasts_refreshes_to ->(ticket) { [ ticket.shop, :kitchen ] }

  # Idempotent submission: retried client_tokens return the existing ticket
  # instead of raising. See CLAUDE.md invariant #2 — do not remove this.
  def self.submit!(table_session:, client_token:, placed_by:, items_attributes:)
    create!(
      table_session: table_session,
      client_token: client_token,
      placed_by: placed_by,
      number: table_session.tickets.count + 1,
      placed_at: Time.current,
      ticket_items_attributes: items_attributes
    )
  rescue ActiveRecord::RecordNotUnique
    find_by!(client_token: client_token)
  end
end
