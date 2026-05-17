class Receipt < ApplicationRecord
  CATEGORIES = %w[food transport lodging sightseeing other].freeze

  belongs_to :trip

  validates :amount, numericality: { greater_than: 0 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :description, length: { maximum: 200 }

  scope :ordered, -> { order(spent_on: :desc, id: :desc) }
end
