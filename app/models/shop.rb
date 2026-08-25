class Shop < ApplicationRecord
  include ApiSyncEmitting
  # A shared operational PIN handed out verbally by admin to staff pairing
  # a new device — same trust model as a WiFi password, not a personal
  # credential. Stored in the clear so admin can look it up and read it
  # off any time from Settings; see the migration for why hashing it made
  # the actual "how does staff learn this PIN" question unanswerable.
  validates :pairing_pin, format: { with: /\A\d{4}\z/, message: "must be exactly 4 digits" }, allow_nil: true

  # Enforces the single-shop-per-deployment invariant everything else here
  # (ShopScoped's default_scope, Authentication#set_current_shop) quietly
  # assumes. Without this, a second row — created by a bug, a bad console
  # command, a botched import — would sit there with undefined behavior:
  # Shop.first has no ORDER BY, so which shop's data every request sees
  # would depend on Postgres row-return order, not on anything the app
  # controls. See ARCHITECTURE.md §11 for the real multi-tenancy path;
  # this is not that, it's making the current single-shop assumption fail
  # loudly instead of silently, if it's ever violated.
  validate :only_one_shop_may_exist, on: :create

  has_many :users, dependent: :restrict_with_error
  has_many :admin_users, dependent: :restrict_with_error
  has_many :devices, dependent: :restrict_with_error
  has_many :dining_tables, dependent: :restrict_with_error
  has_many :table_sessions, dependent: :restrict_with_error
  has_many :menu_items, dependent: :restrict_with_error
  has_many :tickets, dependent: :restrict_with_error
  has_many :invoices, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :print_jobs, dependent: :restrict_with_error
  has_many :audit_events, dependent: :restrict_with_error
  has_many :pairing_attempts, dependent: :restrict_with_error
  has_many :held_carts, dependent: :destroy
  has_many :client_actions, dependent: :restrict_with_error
  has_many :invoice_authority_grants, dependent: :restrict_with_error
  has_many :api_sync_events, dependent: :restrict_with_error
  has_one :sync_cursor, class_name: "ShopSyncCursor", dependent: :destroy

  validates :name, presence: true
  validates :state_code, presence: true
  validates :invoice_prefix, presence: true
  validates :invoice_fy, presence: true
  validates :gst_rate_bp, numericality: { greater_than_or_equal_to: 0 }
  validates :invoice_sequence, numericality: { greater_than_or_equal_to: 0 }

  def authenticate_pairing_pin(candidate)
    pairing_pin.present? && ActiveSupport::SecurityUtils.secure_compare(pairing_pin, candidate.to_s)
  end

  # Delegates to ShopSyncCursor so incrementing it is never itself a write
  # to this row — see db/migrate/*_create_shop_sync_cursors.
  def api_sync_cursor
    ShopSyncCursor.value_for(self)
  end

  # India's financial year runs 1 April to 31 March.
  def self.financial_year_for(date)
    date.month >= 4 ? "#{date.year}-#{(date.year + 1) % 100}" : "#{date.year - 1}-#{date.year % 100}"
  end

  # Row-locks the shop and increments the gapless per-FY invoice counter.
  # Must be called inside the invoice-creating transaction.
  def next_invoice_sequence!(financial_year)
    reload_invoice_fy_if_rolled_over!(financial_year)
    increment!(:invoice_sequence)
    invoice_sequence
  end

  private

  def reload_invoice_fy_if_rolled_over!(financial_year)
    return if invoice_fy == financial_year

    update!(invoice_fy: financial_year, invoice_sequence: 0)
  end

  def only_one_shop_may_exist
    errors.add(:base, "a shop already exists — this deployment is single-shop only") if Shop.exists?
  end

  # Mirrors Api::V1::BootstrapController#shop_payload's field set — the
  # fields Nepal-facing clients need to notice changing (e.g.
  # service_charge_enabled flipping, a fiscal-year rollover), not every
  # column. Update alongside that payload when Phase B/C renames land.
  def api_sync_record
    {
      id: id, name: name, address: address, gstin: gstin, fssai_licence: fssai_licence,
      state_code: state_code, gst_rate_bp: gst_rate_bp, composition_scheme: composition_scheme,
      prices_include_tax: prices_include_tax, invoice_fy: invoice_fy,
      invoice_prefix: invoice_prefix, invoice_footer: invoice_footer
    }
  end
end
