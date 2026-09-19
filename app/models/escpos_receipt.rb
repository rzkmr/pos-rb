# Builds the raw ESC/POS byte sequence for an 80mm thermal printer.
# See ARCHITECTURE.md §7 — raw bytes over TCP:9100, no printer driver gem.
class EscposReceipt
  ESC = "\x1B".freeze
  GS = "\x1D".freeze
  INIT = "#{ESC}@".freeze
  ALIGN_CENTER = "#{ESC}a\x01".freeze
  ALIGN_LEFT = "#{ESC}a\x00".freeze
  BOLD_ON = "#{ESC}E\x01".freeze
  BOLD_OFF = "#{ESC}E\x00".freeze
  DOUBLE_HEIGHT_ON = "#{GS}!\x01".freeze
  DOUBLE_HEIGHT_OFF = "#{GS}!\x00".freeze
  CUT = "#{GS}V\x01".freeze
  LINE_WIDTH = 42

  def self.build(invoice:, duplicate: false)
    new(invoice: invoice, duplicate: duplicate).build
  end

  def initialize(invoice:, duplicate:)
    @invoice = invoice
    @shop = invoice.shop
    @table_session = invoice.table_session
    @duplicate = duplicate
  end

  def build
    lines = []
    lines << INIT
    lines << ALIGN_CENTER
    lines << BOLD_ON << DOUBLE_HEIGHT_ON << "#{@shop.name}\n" << DOUBLE_HEIGHT_OFF << BOLD_OFF
    lines << "#{@shop.address}\n" if @shop.address.present?
    lines << "PAN: #{@shop.pan}\n" if @shop.pan.present?
    lines << BOLD_ON << "*** DUPLICATE ***\n" << BOLD_OFF if @duplicate
    lines << ALIGN_LEFT
    lines << divider
    lines << "Invoice: #{@invoice.number}\n"
    lines << "Date: #{@invoice.issued_at.strftime('%d-%b-%Y %H:%M')}\n"
    lines << "Table: #{@table_session.dining_table.label}\n"
    lines << divider
    lines << item_lines
    lines << divider
    lines << money_line("Subtotal", @invoice.base_paisa)
    lines << money_line("Service Charge", @invoice.service_charge_paisa)
    lines << money_line("VAT", @invoice.vat_paisa)
    lines << BOLD_ON << money_line("TOTAL", @invoice.gross_paisa) << BOLD_OFF
    lines << divider
    lines << ALIGN_CENTER << "#{@shop.invoice_footer}\n" if @shop.invoice_footer.present?
    lines << "\n\n\n"
    lines << CUT
    lines.join
  end

  private

  def item_lines
    @table_session.tickets.flat_map { |ticket| ticket.ticket_items.active }.map do |item|
      "#{item.quantity} x #{item.name_snapshot}".ljust(LINE_WIDTH - 10) +
        money(item.quantity * item.unit_price_paisa).rjust(10) + "\n"
    end.join
  end

  def money_line(label, paisa)
    label.ljust(LINE_WIDTH - 10) + money(paisa).rjust(10) + "\n"
  end

  def money(paisa)
    "Rs.#{(paisa.to_i.fdiv(100)).round(2)}"
  end

  def divider
    ("-" * LINE_WIDTH) + "\n"
  end
end
