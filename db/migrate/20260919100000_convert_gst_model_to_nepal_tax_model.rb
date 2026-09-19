# Replaces the India-GST fields this schema was originally built with
# (GSTIN, CGST/SGST split, HSN/SAC, composition scheme, Gregorian FY)
# with Nepal's VAT + service-charge model — CLAUDE.md invariants #2, #3,
# #8. See ARCHITECTURE.md for why the original scaffold was India-shaped.
#
# `_paise` (India spelling) becomes `_paisa` (CLAUDE.md invariant #1)
# everywhere it appears on these two tables.
class ConvertGstModelToNepalTaxModel < ActiveRecord::Migration[8.1]
  def up
    change_table :shops, bulk: true do |t|
      t.remove :gstin, :state_code, :fssai_licence, :gst_rate_bp, :composition_scheme, :prices_include_tax
      t.string :pan
      t.integer :vat_rate_bp, null: false, default: 1300   # 13%
      t.integer :service_charge_rate_bp, null: false, default: 1000 # 10%
    end

    change_table :invoices, bulk: true do |t|
      t.remove :cgst_paise, :sgst_paise, :taxable_paise, :total_paise, :customer_gstin, :gstin_snapshot
      t.integer :base_paisa
      t.integer :service_charge_paisa
      t.integer :vat_paisa
      t.integer :gross_paisa
    end
    # Backfill in two steps (rename-shaped fields carry no data since this
    # is a pre-launch single-shop deployment — see CLAUDE.md "single shop
    # in production" — but NOT NULL is applied only after the column
    # exists, the safe order for any environment that does have rows).
    execute "UPDATE invoices SET base_paisa = 0, service_charge_paisa = 0, vat_paisa = 0, gross_paisa = 0 WHERE base_paisa IS NULL"
    change_column_null :invoices, :base_paisa, false
    change_column_null :invoices, :service_charge_paisa, false
    change_column_null :invoices, :vat_paisa, false
    change_column_null :invoices, :gross_paisa, false

    rename_column :invoices, :round_off_paise, :round_off_paisa

    change_table :menu_items, bulk: true do |t|
      t.remove :hsn_sac
    end
    rename_column :menu_items, :price_paise, :gross_price_paisa

    rename_column :payments, :amount_paise, :amount_paisa
    rename_column :table_sessions, :discount_paise, :discount_paisa
    rename_column :ticket_items, :unit_price_paise, :unit_price_paisa
    remove_column :ticket_items, :hsn_sac_snapshot, :string, null: false
  end

  def down
    change_table :shops, bulk: true do |t|
      t.remove :pan, :vat_rate_bp, :service_charge_rate_bp
      t.string :gstin
      t.string :state_code, null: false, default: "00"
      t.string :fssai_licence
      t.integer :gst_rate_bp, null: false, default: 500
      t.boolean :composition_scheme, null: false, default: false
      t.boolean :prices_include_tax, null: false, default: false
    end

    change_table :invoices, bulk: true do |t|
      t.remove :base_paisa, :service_charge_paisa, :vat_paisa, :gross_paisa
      t.integer :taxable_paise
      t.integer :cgst_paise
      t.integer :sgst_paise
      t.integer :total_paise
      t.string :customer_gstin
      t.string :gstin_snapshot
    end
    execute "UPDATE invoices SET taxable_paise = 0, cgst_paise = 0, sgst_paise = 0, total_paise = 0 WHERE taxable_paise IS NULL"
    change_column_null :invoices, :taxable_paise, false
    change_column_null :invoices, :cgst_paise, false
    change_column_null :invoices, :sgst_paise, false
    change_column_null :invoices, :total_paise, false

    rename_column :invoices, :round_off_paisa, :round_off_paise

    rename_column :menu_items, :gross_price_paisa, :price_paise
    add_column :menu_items, :hsn_sac, :string, null: false, default: "996331"

    rename_column :payments, :amount_paisa, :amount_paise
    rename_column :table_sessions, :discount_paisa, :discount_paise
    rename_column :ticket_items, :unit_price_paisa, :unit_price_paise
    add_column :ticket_items, :hsn_sac_snapshot, :string, null: false, default: "996331"
  end
end
