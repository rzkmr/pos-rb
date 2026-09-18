class TicketItem < ApplicationRecord
  include BikramSambatDated

  bs_dates_for :voided_at

  belongs_to :ticket
  belongs_to :menu_item
  belongs_to :voided_by, class_name: "User", optional: true

  before_validation :snapshot_from_menu_item, on: :create

  validates :name_snapshot, presence: true
  validates :hsn_sac_snapshot, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_paise, numericality: { greater_than_or_equal_to: 0 }
  validates :void_reason, presence: true, if: -> { voided_at.present? }

  scope :active, -> { where(voided_at: nil) }

  def void!(reason:, by:)
    update!(voided_at: Time.current, void_reason: reason, voided_by: by)
  end

  private

  # Snapshots, not joins — a later menu edit must never alter a past bill.
  def snapshot_from_menu_item
    return unless menu_item

    self.name_snapshot ||= menu_item.name
    self.hsn_sac_snapshot ||= menu_item.hsn_sac
    self.unit_price_paise ||= menu_item.price_paise
  end
end
