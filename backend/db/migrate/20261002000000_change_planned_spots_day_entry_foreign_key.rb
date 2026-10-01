# Issue #160: 日記が消えたら、昇格元の予定のスポットの参照を空にする
# (on_delete が無いと、旅行や日記を消すときに外部キーで失敗する)
class ChangePlannedSpotsDayEntryForeignKey < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :planned_spots, :day_entries
    add_foreign_key :planned_spots, :day_entries, on_delete: :nullify
  end
end
