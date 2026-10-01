class DayEntry < ApplicationRecord
  belongs_to :trip, inverse_of: :day_entries
  # Issue #160: 予定から昇格した日記を消しても、予定のスポットは残す (参照だけ空にする)
  has_many :planned_spots, dependent: :nullify

  validates :title, presence: true, length: { maximum: 80 }
  validates :body, length: { maximum: 2000 }
  validates :day_number, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
end
