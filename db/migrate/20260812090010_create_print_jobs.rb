class CreatePrintJobs < ActiveRecord::Migration[8.1]
  def up
    create_table :print_jobs do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "queued"
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :sent_at

      t.timestamps
    end

    add_index :print_jobs, [ :shop_id, :status ]
  end

  def down
    drop_table :print_jobs
  end
end
