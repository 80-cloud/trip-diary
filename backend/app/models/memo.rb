class Memo < ApplicationRecord
  MAX_BODY = 2000

  belongs_to :user
  belongs_to :trip

  validates :body, presence: true, length: { maximum: MAX_BODY }
  validates :user_id, uniqueness: { scope: :trip_id }
end
