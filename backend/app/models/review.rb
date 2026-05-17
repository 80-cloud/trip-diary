class Review < ApplicationRecord
  MAX_BODY = 2000

  belongs_to :trip

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :body, length: { maximum: MAX_BODY }, allow_blank: true
  validates :trip_id, uniqueness: true
end
