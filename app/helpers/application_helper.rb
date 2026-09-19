module ApplicationHelper
  # The only place paisa becomes a displayed rupee amount. See CLAUDE.md
  # invariant #1 — never format money anywhere else. Devanagari numerals
  # are render-only (invariant #7) and money is always Arabic, so this
  # never routes through Nepali numeral formatting.
  def money(paisa)
    rupees = paisa.to_i.fdiv(100)
    number_to_currency(rupees, unit: "Rs. ", precision: 2)
  end
end
