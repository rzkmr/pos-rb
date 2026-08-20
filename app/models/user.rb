class User < ApplicationRecord
  include ShopScoped
  include ApiSyncEmitting

  ROLES = %w[waiter cashier kitchen].freeze
  LOCALES = %w[en ne].freeze

  # A shared-tablet PIN with no self-service reset — if staff forget it
  # mid-shift, admin is the only recourse. Stored in the clear (not
  # has_secure_password) so admin can read the current PIN back to them
  # instead of being forced to hand out a new one every time; see the
  # migration for the full reasoning.
  has_many :table_sessions, foreign_key: :opened_by_id, inverse_of: :opened_by, dependent: :restrict_with_error
  has_many :tickets, foreign_key: :placed_by_id, inverse_of: :placed_by, dependent: :restrict_with_error
  has_many :payments, foreign_key: :received_by_id, inverse_of: :received_by, dependent: :restrict_with_error
  has_many :audit_events, dependent: :restrict_with_error

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :pin, presence: true, format: { with: /\A\d{4}\z/, message: "must be 4 digits" }
  validates :locale, inclusion: { in: LOCALES }

  scope :active, -> { where(active: true) }

  def authenticate_pin(candidate)
    pin.present? && ActiveSupport::SecurityUtils.secure_compare(pin, candidate.to_s)
  end

  private

  # PIN never leaves the server in an API payload — see
  # CatalogSnapshotsController's identical omission.
  def api_sync_record
    { id: id, name: name, role: role, active: active }
  end
end
