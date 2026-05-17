class PlannedSpot < ApplicationRecord
  belongs_to :trip
  # F-PLAN-02: done=true 時に紐付ける DayEntry (optional)
  belongs_to :day_entry, optional: true

  validates :title, presence: true, length: { maximum: 80 }

  scope :ordered, -> { order(:position, :id) }

  # done を false→true に切り替えた瞬間に DayEntry を作成して紐付ける (冪等)。
  # done=true→false に戻す場合は DayEntry を消さない (UX 上、誤操作からの復元手段として残す)。
  after_update_commit :promote_to_day_entry, if: -> { saved_change_to_done? && done? }

  private

  def promote_to_day_entry
    return if day_entry_id.present? # 既に昇格済 → 重複作成しない (冪等)

    day = trip.day_entries.create!(
      day_number: (trip.day_entries.maximum(:day_number) || 0) + 1,
      title: title,
      position: (trip.day_entries.maximum(:position) || 0) + 1
    )
    update_columns(day_entry_id: day.id)
  end
end
