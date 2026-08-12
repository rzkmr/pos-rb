# Web login for admin (menu, users, tables, sales, settings). Separate from
# User/Device+PIN, which is the shared-tablet system for shop-floor roles.
# See ARCHITECTURE.md/CLAUDE.md §8 — admin is a real credential, not a PIN.
class AdminUser < ApplicationRecord
  include ShopScoped

  has_secure_password

  has_many :audit_events, dependent: :restrict_with_error

  validates :username, presence: true, uniqueness: { scope: :shop_id, case_sensitive: false }
  validates :password, length: { minimum: 8 }, if: -> { password_digest.blank? || password.present? }

  scope :active, -> { where(active: true) }

  before_validation { self.username = username&.downcase }
end
