module ApplicationHelper
  # The only place paise becomes a displayed rupee amount. See CLAUDE.md
  # invariant #1 — never format money anywhere else.
  def money_to_inr(paise)
    rupees = paise.to_i.fdiv(100)
    number_to_currency(rupees, unit: "₹", precision: 2)
  end
end
