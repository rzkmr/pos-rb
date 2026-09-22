# Makes every foreign key DEFERRABLE INITIALLY DEFERRED — constraint
# checks move from per-statement to transaction-commit.
#
# Why: Rails' fixture loader tries to disable FK-check triggers for a
# bulk load (ActiveRecord::ConnectionAdapters::PostgreSQL::
# ReferentialIntegrity#disable_referential_integrity), which needs
# Postgres superuser. Without it, Rails silently falls back to a real,
# FK-checked batch insert in fixture-file alphabetical order (Rails
# always .sorts fixture_table_names — there is no supported way to
# control load order), which breaks the moment any fixture file sorts
# before a table it references (admin_users.yml before shops.yml, here).
#
# Deferring the check to COMMIT makes insertion order inside one
# transaction irrelevant — exactly what a bulk fixture load is — without
# requiring the trigger-disable privilege at all. This is the standard
# fix for this class of problem and has no visible effect on ordinary
# app code: a transaction that violates a FK still fails, just at
# COMMIT instead of at the violating INSERT/UPDATE, and every write in
# this app already runs inside a transaction that's expected to succeed
# or roll back as a whole (Billing, Ticket.submit!, Sync::Replay, etc.)
# — nothing here relies on seeing a mid-transaction FK failure early.
class MakeForeignKeysDeferrable < ActiveRecord::Migration[8.1]
  def up
    each_foreign_key do |from_table, fk|
      next if fk.options[:deferrable] == :deferred

      remove_foreign_key from_table, name: fk.name
      add_foreign_key from_table, fk.to_table,
        **fk.options.except(:deferrable).merge(name: fk.name, deferrable: :deferred)
    end
  end

  def down
    each_foreign_key do |from_table, fk|
      next unless fk.options[:deferrable] == :deferred

      remove_foreign_key from_table, name: fk.name
      add_foreign_key from_table, fk.to_table, **fk.options.except(:deferrable).merge(name: fk.name)
    end
  end

  private

  def each_foreign_key
    tables.each do |table|
      foreign_keys(table).each { |fk| yield table, fk }
    end
  end
end
