# Computes GST on the session subtotal (never per line — CLAUDE.md invariant #7)
# and issues the gapless per-financial-year invoice (invariant #5).
class Billing
  Result = Struct.new(:taxable_paise, :cgst_paise, :sgst_paise, :round_off_paise, :total_paise, keyword_init: true)

  def self.compute(shop:, taxable_paise:)
    return Result.new(taxable_paise: taxable_paise, cgst_paise: 0, sgst_paise: 0, round_off_paise: 0, total_paise: taxable_paise) if shop.composition_scheme

    half_rate_bp = shop.gst_rate_bp / 2.0
    cgst_paise = (taxable_paise * half_rate_bp / 10_000).round
    sgst_paise = cgst_paise

    pre_round_total = taxable_paise + cgst_paise + sgst_paise
    total_paise = (pre_round_total / 100.0).round * 100
    round_off_paise = total_paise - pre_round_total

    Result.new(
      taxable_paise: taxable_paise,
      cgst_paise: cgst_paise,
      sgst_paise: sgst_paise,
      round_off_paise: round_off_paise,
      total_paise: total_paise
    )
  end

  def self.issue_invoice!(table_session:)
    shop = table_session.shop
    result = compute(shop: shop, taxable_paise: table_session.subtotal_paise)
    financial_year = Shop.financial_year_for(Date.current)

    shop.with_lock do
      sequence = shop.next_invoice_sequence!(financial_year)
      table_session.invoices.create!(
        shop: shop,
        number: "#{shop.invoice_prefix}/#{financial_year}/#{sequence.to_s.rjust(5, '0')}",
        financial_year: financial_year,
        sequence: sequence,
        issued_at: Time.current,
        taxable_paise: result.taxable_paise,
        cgst_paise: result.cgst_paise,
        sgst_paise: result.sgst_paise,
        round_off_paise: result.round_off_paise,
        total_paise: result.total_paise,
        gstin_snapshot: shop.gstin
      )
    end
  end
end
