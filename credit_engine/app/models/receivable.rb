class Receivable < ApplicationRecord
  belongs_to :operation
  belongs_to :receivable_type
  belongs_to :currency

  validates :identifier, presence: true
  validates :face_value, presence: true, numericality: { greater_than: 0 }
  validates :net_value, presence: true, numericality: { greater_than: 0 }
  validates :due_date, presence: true
  validates :days_to_maturity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :spread_applied, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :base_rate_applied, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :exchange_rate_applied, numericality: { greater_than: 0 }, allow_nil: true
end
