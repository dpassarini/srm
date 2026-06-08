class CreateExchangeRates < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_rates do |t|
      t.references :from_currency, null: false, foreign_key: { to_table: :currencies }
      t.references :to_currency, null: false, foreign_key: { to_table: :currencies }
      t.decimal :rate, precision: 18, scale: 8, null: false
      t.date :reference_date, null: false

      t.timestamps
    end
    add_index :exchange_rates, [:from_currency_id, :to_currency_id, :reference_date], unique: true, name: 'index_exchange_rates_on_currencies_and_date'
  end
end
