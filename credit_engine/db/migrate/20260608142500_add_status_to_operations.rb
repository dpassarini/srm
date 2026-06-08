class AddStatusToOperations < ActiveRecord::Migration[8.1]
  def change
    add_column :operations, :status, :string, default: "pending", null: false
  end
end
