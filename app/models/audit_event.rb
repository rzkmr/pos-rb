class AuditEvent < ApplicationRecord
  include ShopScoped

  belongs_to :user, optional: true
  belongs_to :admin_user, optional: true
  belongs_to :device, optional: true
  belongs_to :subject, polymorphic: true

  validates :action, presence: true
  validate :exactly_one_actor

  # Append-only: voids, comps, discounts, price edits, reprints.
  # See CLAUDE.md invariant #8 — do not add update/destroy paths.
  def readonly?
    persisted?
  end

  # Exactly one of user:/admin_user: — a shop-floor PIN actor or a web
  # admin login, never both, never neither.
  def self.record!(action:, subject:, user: nil, admin_user: nil, device: nil, payload: {})
    create!(
      action: action,
      subject: subject,
      user: user,
      admin_user: admin_user,
      device: device,
      payload: payload
    )
  end

  private

  def exactly_one_actor
    return if [ user, admin_user ].compact.size == 1

    errors.add(:base, "exactly one of user or admin_user must be set")
  end
end
