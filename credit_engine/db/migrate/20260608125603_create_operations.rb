class CreateOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :operations do |t|
      t.string :assignee, null: false
      t.references :payment_currency, null: false, foreign_key: { to_table: :currencies }
      t.decimal :total_face_value, precision: 18, scale: 4, null: false
      t.decimal :total_net_value, precision: 18, scale: 4, null: false

      t.timestamps
    end
  end
end
