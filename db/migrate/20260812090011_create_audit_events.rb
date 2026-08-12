class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def up
    create_table :audit_events do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :device, foreign_key: true
      t.string :action, null: false
      t.string :subject_type, null: false
      t.integer :subject_id, null: false
      t.json :payload, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :audit_events, [ :shop_id, :subject_type, :subject_id ]
  end

  def down
    drop_table :audit_events
  end
end
