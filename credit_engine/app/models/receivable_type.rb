class ReceivableType < ApplicationRecord
  has_many :receivables, dependent: :restrict_with_error

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :base_spread, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
