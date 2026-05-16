class Comment < ApplicationRecord
  belongs_to :trip, counter_cache: true
  belongs_to :user

  validates :body, presence: true, length: { maximum: 140 }
end
