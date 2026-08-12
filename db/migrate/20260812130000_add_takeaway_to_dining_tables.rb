class AddTakeawayToDiningTables < ActiveRecord::Migration[8.1]
  def up
    add_column :dining_tables, :takeaway, :boolean, null: false, default: false
  end

  def down
    remove_column :dining_tables, :takeaway
  end
end
