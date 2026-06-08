class Currency < ApplicationRecord
  has_many :exchange_rates_from, class_name: 'ExchangeRate', foreign_key: :from_currency_id, dependent: :destroy
  has_many :exchange_rates_to, class_name: 'ExchangeRate', foreign_key: :to_currency_id, dependent: :destroy
  has_many :operations_paid, class_name: 'Operation', foreign_key: :payment_currency_id, dependent: :restrict_with_error
  has_many :receivables, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :symbol, presence: true
end
