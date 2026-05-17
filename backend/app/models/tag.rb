class Tag < ApplicationRecord
  has_many :trip_tags, dependent: :destroy
  has_many :trips, through: :trip_tags

  validates :name, presence: true, uniqueness: true, length: { maximum: 32 }

  scope :popular, ->(limit = 20) { order(trips_count: :desc, id: :asc).limit(limit) }

  # 入力配列を strip + 空文字除去 + ユニーク化したうえで、既存タグを再利用し
  # 不足分のみ新規作成する。順序はリクエスト順を保つ。
  def self.find_or_create_by_names(names)
    cleaned = Array(names).map { |n| n.to_s.strip }.reject(&:blank?).uniq
    return [] if cleaned.empty?

    existing = where(name: cleaned).index_by(&:name)
    cleaned.map { |name| existing[name] ||= create!(name: name) }
  end
end
