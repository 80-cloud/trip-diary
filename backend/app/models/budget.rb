class Budget < ApplicationRecord
  CURRENCIES = %w[JPY USD EUR GBP KRW CNY TWD].freeze

  belongs_to :trip

  validates :trip_id, uniqueness: true
  validates :planned_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, inclusion: { in: CURRENCIES }
end
