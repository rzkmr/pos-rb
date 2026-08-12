# Aggregates a shop's invoices and payments for one calendar day, for the
# admin reconciliation screen — total sales vs. till by payment method.
class DailySales
  ByMethod = Struct.new(:method, :total_paise, keyword_init: true)

  attr_reader :shop, :date

  def initialize(shop:, date:)
    @shop = shop
    @date = date
  end

  def range
    date.beginning_of_day..date.end_of_day
  end

  def invoices
    @invoices ||= shop.invoices.where(issued_at: range).order(:sequence)
  end

  def payments
    @payments ||= shop.payments.where(created_at: range)
  end

  def invoice_total_paise
    invoices.sum(:total_paise)
  end

  def payment_total_paise
    payments.sum(:amount_paise)
  end

  def by_payment_method
    totals = payments.group(:method).sum(:amount_paise)
    Payment::METHODS.map { |method| ByMethod.new(method: method, total_paise: totals.fetch(method, 0)) }
  end

  def void_count
    TicketItem.joins(ticket: :table_session)
      .where(table_sessions: { shop_id: shop.id })
      .where.not(voided_at: nil)
      .where(voided_at: range)
      .count
  end

  def reprint_count
    shop.print_jobs.where(kind: "duplicate", created_at: range).count
  end
end
