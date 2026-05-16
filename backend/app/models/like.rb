class Like < ApplicationRecord
  belongs_to :trip, counter_cache: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: :trip_id }
end
