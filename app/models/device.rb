class Device < ApplicationRecord
  include ShopScoped

  KINDS = %w[waiter kitchen cashier admin].freeze

  has_secure_password :token, validations: false

  has_many :audit_events, dependent: :nullify

  validates :label, presence: true
  validates :kind, inclusion: { in: KINDS }

  # Generates the plaintext token (returned once, never stored) and sets token_digest.
  def self.pair!(shop:, label:, kind:)
    token = SecureRandom.urlsafe_base64(32)
    device = create!(shop: shop, label: label, kind: kind, token: token)
    [ device, token ]
  end

  def touch_last_seen!
    update_column(:last_seen_at, Time.current)
  end
end
