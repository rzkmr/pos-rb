class CreateInvoiceAuthorityGrants < ActiveRecord::Migration[8.1]
  def change
    # The single-writer lock that makes offline invoice issuance safe
    # (CLAUDE.md invariant #5). At most one LIVE grant may exist per shop —
    # enforced by the database via the partial unique index below, not just
    # application logic, so a race between two grant requests loses at the
    # index rather than at an `if !exists?` check. While a device holds a
    # live grant, every other invoice-issuing path in the app must raise
    # (see Billing.issue_invoice!'s guard) — that's the whole safety
    # property this table exists to make enforceable.
    create_table :invoice_authority_grants do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :device, null: false, foreign_key: true
      t.string :financial_year, null: false
      t.integer :granted_sequence, null: false
      t.integer :last_reported_sequence
      t.datetime :granted_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :released_at
      t.datetime :reconciled_at

      t.timestamps
    end

    add_index :invoice_authority_grants, :shop_id, unique: true, where: "released_at IS NULL", name: "idx_one_live_grant_per_shop"
    add_index :invoice_authority_grants, [ :shop_id, :device_id ]
  end
end
