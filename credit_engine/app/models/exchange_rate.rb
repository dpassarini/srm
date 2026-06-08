class ExchangeRate < ApplicationRecord
  belongs_to :from_currency, class_name: 'Currency'
  belongs_to :to_currency, class_name: 'Currency'

  validates :rate, presence: true, numericality: { greater_than: 0 }
  validates :reference_date, presence: true
  validates :reference_date, uniqueness: { scope: [:from_currency_id, :to_currency_id], message: "should have only one rate per date" }
end
