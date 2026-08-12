class User < ApplicationRecord
  include ShopScoped

  ROLES = %w[waiter cashier kitchen].freeze
  LOCALES = %w[en ne].freeze

  has_secure_password :pin, validations: false

  has_many :table_sessions, foreign_key: :opened_by_id, inverse_of: :opened_by, dependent: :restrict_with_error
  has_many :tickets, foreign_key: :placed_by_id, inverse_of: :placed_by, dependent: :restrict_with_error
  has_many :payments, foreign_key: :received_by_id, inverse_of: :received_by, dependent: :restrict_with_error
  has_many :audit_events, dependent: :restrict_with_error

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :pin, presence: true, format: { with: /\A\d{4}\z/, message: "must be 4 digits" }, if: -> { pin_digest.blank? || pin.present? }
  validates :locale, inclusion: { in: LOCALES }

  scope :active, -> { where(active: true) }
end
