class TripTag < ApplicationRecord
  belongs_to :trip
  belongs_to :tag, counter_cache: :trips_count

  validates :trip_id, uniqueness: { scope: :tag_id }
end
