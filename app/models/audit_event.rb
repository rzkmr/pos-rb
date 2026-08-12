class AuditEvent < ApplicationRecord
  include ShopScoped

  belongs_to :user
  belongs_to :device, optional: true
  belongs_to :subject, polymorphic: true

  validates :action, presence: true

  # Append-only: voids, comps, discounts, price edits, reprints.
  # See CLAUDE.md invariant #8 — do not add update/destroy paths.
  def readonly?
    persisted?
  end

  def self.record!(action:, subject:, user:, device: nil, payload: {})
    create!(
      action: action,
      subject: subject,
      user: user,
      device: device,
      payload: payload
    )
  end
end
