class Tag < ApplicationRecord
  has_many :trip_tags, dependent: :destroy
  has_many :trips, through: :trip_tags

  validates :name, presence: true, uniqueness: true, length: { maximum: 32 }

  # 公開済みの旅行 (未ログインでも見える旅行) だけで数えた件数の多い順。
  # trips_count (counter cache) は非公開・下書きの旅行も数えるため使わない (Issue #107)。
  # 公開済みの旅行が 0 件のタグは INNER JOIN で除かれる。
  scope :popular, ->(limit = 20) {
    joins(:trips)
      .merge(Trip.visible_to(nil))
      .group(:id)
      .select("tags.*, COUNT(trips.id) AS public_trips_count")
      .order("public_trips_count DESC", id: :asc)
      .limit(limit)
  }

  # 入力配列を strip + 空文字除去 + ユニーク化したうえで、既存タグを再利用し
  # 不足分のみ新規作成する。順序はリクエスト順を保つ。
  def self.find_or_create_by_names(names)
    cleaned = Array(names).map { |n| n.to_s.strip }.reject(&:blank?).uniq
    return [] if cleaned.empty?

    existing = where(name: cleaned).index_by(&:name)
    cleaned.map { |name| existing[name] ||= create!(name: name) }
  end
end
