class TableSession < ApplicationRecord
  include ShopScoped
  include BikramSambatDated

  bs_dates_for :opened_at, :closed_at

  NoTakeawayCounter = Class.new(StandardError)

  STATUSES = %w[open billed paid closed].freeze

  belongs_to :dining_table
  belongs_to :opened_by, class_name: "User"
  belongs_to :discount_approved_by, class_name: "User", optional: true

  has_many :tickets, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :opened_at, presence: true
  validates :discount_paisa, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_reason, presence: true, if: -> { discount_paisa.to_i > 0 }

  scope :open, -> { where(status: "open") }

  def subtotal_paisa
    TicketItem.active.where(ticket: tickets).sum("quantity * unit_price_paisa") - discount_paisa.to_i
  end

  def paid_paisa
    payments.sum(:amount_paisa)
  end

  def apply_discount!(amount_paisa:, reason:, approved_by:)
    update!(discount_paisa: amount_paisa, discount_reason: reason, discount_approved_by: approved_by)
  end

  # A cold-started offline sale (the offline shell) has no real session id
  # to submit against — only a client-generated token. Finds the session
  # that token already resolved to, or creates one against the shop's
  # takeaway counter. Safe under replay/concurrent sync: relies on the
  # unique index on [shop_id, client_session_token], not a check-then-create
  # race, mirroring how Ticket.submit! handles client_token collisions.
  def self.resolve_for_takeaway!(shop:, client_session_token:, opened_by:)
    existing = shop.table_sessions.find_by(client_session_token: client_session_token)
    return existing if existing

    counter = shop.dining_tables.takeaway_counters.first
    raise NoTakeawayCounter, "no takeaway counter configured for this shop" unless counter

    counter.table_sessions.create!(
      client_session_token: client_session_token,
      opened_by: opened_by,
      opened_at: Time.current,
      status: "open"
    )
  rescue ActiveRecord::RecordNotUnique
    shop.table_sessions.find_by!(client_session_token: client_session_token)
  end

  # table_sessions.id is a server-assigned integer — a client can never send
  # its own id and have the server adopt it (see Sync::Handlers::OpenTableSession's
  # KDoc for the incident this fixes). Every client-initiated open instead
  # carries its own client_session_token (a UUID, minted once at the tap
  # that opens the table) and the server hands back the real integer id in
  # the op's result; the client is expected to use that id, not its own
  # token, for every dependent write in the same order (invoice.issue,
  # payment.record, ticket.create, ...) — mirrors Ticket.submit!'s
  # client_token/id split exactly, generalized here to any dining table,
  # not just the takeaway counter resolve_for_takeaway! is scoped to.
  #
  # dining_table's own already-open session (waiter flow: "second waiter
  # reaches the same table") still takes priority over creating a new one —
  # only a session that's genuinely new to this shop is where
  # client_session_token starts mattering.
  # A `table_session_id` payload value arrives in one of two shapes,
  # depending on who's calling: the web admin/PWA already has a real
  # server-assigned integer id (it fetched the session from the server
  # first) and sends that; the Android client never gets one — it can only
  # ever generate its own UUID client-side (see
  # Sync::Handlers::OpenTableSession's KDoc) — and sends that same UUID as
  # both `table_session.open`'s `client_token` AND every dependent op's
  # `table_session_id`. This is the one place that distinguishes the two:
  # an all-digit value is treated as the real id (`find`, matches
  # TakeawayCheckout's own already-established table_session_id branch —
  # see its KDoc); anything else is looked up by client_session_token.
  # Every handler that used to do
  # `@shop.table_sessions.find(payload["table_session_id"])` resolves
  # through here instead. Both branches raise RecordNotFound (never
  # return nil) to keep the existing `rescue ActiveRecord::RecordNotFound`
  # → Rejected pattern every one of those handlers already has.
  def self.resolve!(shop:, table_session_id:)
    if table_session_id.to_s.match?(/\A\d+\z/)
      shop.table_sessions.find(table_session_id)
    else
      shop.table_sessions.find_by!(client_session_token: table_session_id)
    end
  end

  # Note: `guest_count` travels in the client's payload but has no column
  # here yet — silently dropped both before and after this change, a
  # separate pre-existing gap, not something this fix is scoped to close.
  def self.resolve_or_open!(shop:, dining_table:, client_session_token:, opened_by:)
    existing = shop.table_sessions.find_by(client_session_token: client_session_token)
    return existing if existing

    open_on_table = dining_table.open_session
    return open_on_table if open_on_table

    dining_table.table_sessions.create!(
      client_session_token: client_session_token,
      opened_by: opened_by,
      opened_at: Time.current,
      status: "open"
    )
  rescue ActiveRecord::RecordNotUnique
    shop.table_sessions.find_by!(client_session_token: client_session_token)
  end
end
