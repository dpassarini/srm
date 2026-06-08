class Operation < ApplicationRecord
  belongs_to :payment_currency, class_name: "Currency"
  has_many :receivables, dependent: :destroy

  accepts_nested_attributes_for :receivables

  validates :assignee, presence: true
  validates :total_face_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_net_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
