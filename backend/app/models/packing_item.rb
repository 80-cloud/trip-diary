class PackingItem < ApplicationRecord
  belongs_to :trip

  validates :body, presence: true, length: { maximum: 80 }

  scope :ordered, -> { order(:position, :id) }
end
