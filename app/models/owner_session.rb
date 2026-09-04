# Long-lived, revocable credential for the Android app's Admin screen —
# API-SPEC.md §1a. Same shape as Device's token: plaintext is returned once
# from Api::V1::Owner::SessionsController#create and never stored, only
# token_digest persists. Separate from Device — an owner session identifies
# the person, not the terminal, and is revoked independently of pairing.
class OwnerSession < ApplicationRecord
  include ShopScoped

  belongs_to :admin_user

  has_secure_password :token, validations: false

  def self.issue!(admin_user:)
    token = SecureRandom.urlsafe_base64(32)
    session = create!(shop: admin_user.shop, admin_user: admin_user, token: token)
    [ session, token ]
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end
end
