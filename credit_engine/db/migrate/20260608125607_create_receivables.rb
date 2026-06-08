class CreateReceivables < ActiveRecord::Migration[8.1]
  def change
    create_table :receivables do |t|
      t.references :operation, null: false, foreign_key: true
      t.references :receivable_type, null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.string :identifier, null: false
      t.decimal :face_value, precision: 18, scale: 4, null: false
      t.decimal :net_value, precision: 18, scale: 4, null: false
      t.date :due_date, null: false
      t.integer :days_to_maturity, null: false
      t.decimal :spread_applied, precision: 6, scale: 4, null: false
      t.decimal :base_rate_applied, precision: 6, scale: 4, null: false
      t.decimal :exchange_rate_applied, precision: 18, scale: 8

      t.timestamps
    end
  end
end
