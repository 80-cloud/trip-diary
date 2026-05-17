class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :trip

  validates :user_id, uniqueness: { scope: :trip_id }
end
