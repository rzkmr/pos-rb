class Ticket < ApplicationRecord
  include ShopScoped

  STATUSES = %w[pending preparing ready served].freeze

  belongs_to :table_session
  belongs_to :placed_by, class_name: "User"

  has_many :ticket_items, dependent: :restrict_with_error
  accepts_nested_attributes_for :ticket_items

  validates :client_token, presence: true
  validates :number, presence: true
  validates :placed_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  broadcasts_refreshes_to ->(ticket) { [ ticket.shop, :kitchen ] }

  # Idempotent submission: retried client_tokens return the existing ticket
  # instead of raising. See CLAUDE.md invariant #2 — do not remove this.
  #
  # requires_new: true opens a savepoint. Without it, a RecordNotUnique
  # under Postgres poisons the *enclosing* transaction (not just this
  # statement) — every later query in that transaction, including the
  # find_by! below, fails with "current transaction is aborted". Callers
  # that wrap submit! in their own transaction (e.g. an atomic
  # order+payment checkout) would otherwise break on every retry.
  def self.submit!(table_session:, client_token:, placed_by:, items_attributes:)
    transaction(requires_new: true) do
      create!(
        table_session: table_session,
        client_token: client_token,
        placed_by: placed_by,
        number: table_session.tickets.count + 1,
        placed_at: Time.current,
        ticket_items_attributes: items_attributes
      )
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(client_token: client_token)
  end
end
