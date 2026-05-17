class Trip < ApplicationRecord
  VISIBILITIES = %w[public friends private].freeze

  # 表示名 (国内 / 海外 / 一人旅 / グルメ / 世界遺産 / 家族旅 / アウトドア / 出張) は
  # フロントで i18n 切替できるよう、DB には symbol を保存する。
  enum :category, {
    domestic: "domestic",
    overseas: "overseas",
    solo:     "solo",
    gourmet:  "gourmet",
    heritage: "heritage",
    family:   "family",
    outdoor:  "outdoor",
    business: "business"
  }

  # 下書き / 公開済の 2 値。default: :published で省略時に Trip.new が
  # NOT NULL 違反にならないようにする (DB 側 default は enum バリデーション発火のため敢えて持たない)。
  enum :status, { draft: "draft", published: "published" }, default: :published

  belongs_to :user
  has_many :day_entries, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :trip
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :liking_users, through: :likes, source: :user
  has_many :trip_tags, dependent: :destroy
  has_many :tags, through: :trip_tags
  has_many :favorites, dependent: :destroy
  has_many :memos,     dependent: :destroy
  # has_many に order を入れることで、eager load (includes :planned_spots) 結果が
  # そのまま position 順で取れる。controller 側で .ordered を再度呼ぶ必要がなくなり
  # (=N+1 防止)、Ruby の sort_by よりも DB index を活用できる。
  has_many :planned_spots, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :trip
  has_many :packing_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :trip
  has_many :tickets, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :trip
  has_one :review, dependent: :destroy
  has_many_attached :images

  accepts_nested_attributes_for :day_entries, allow_destroy: true, reject_if: :all_blank

  validates :title, presence: true, length: { maximum: 80 }
  validates :destination, presence: true, length: { maximum: 80 }
  validates :started_on, :ended_on, presence: true
  validates :body, length: { maximum: 5000 }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :category, presence: true
  validate :end_after_start
  validate :images_count_within_limit
  validate :images_size_within_limit
  validate :tag_list_within_limits

  scope :recent, -> { order(created_at: :desc) }

  # visibility (公開範囲) と status (公開状態) を組み合わせた可視性。
  # - 本人: 自分の全 trip (draft / private 含む)
  # - 他人:
  #   - public + published: 全ユーザー可視
  #   - friends + published: trip 投稿者と「相互フォロー」しているユーザーのみ可視
  #   - private: 不可視
  # 未ログイン: public + published のみ
  scope :visible_to, ->(user) {
    if user
      # 相互フォロー: 「自分がフォローしてる人」∩「自分をフォローしてる人」
      mutual_ids = user.followings.pluck(:id) & user.followers.pluck(:id)
      where(
        "(visibility = ? AND status = ?) " \
        "OR (visibility = ? AND status = ? AND user_id IN (?)) " \
        "OR user_id = ?",
        "public", "published",
        "friends", "published", mutual_ids.presence || [-1],
        user.id
      )
    else
      where(visibility: "public", status: "published")
    end
  }

  # F-UX-INF-SCROLL: id 降順の cursor pagination。
  # cursor (= 前ページ末尾の id) より小さい id を返す。
  # `sorted(:recent)` の `created_at DESC, id DESC` と整合 (autoincrement で id と created_at は単調増加)。
  # popular/title sort では cursor を使わない (offset でも実装可だが本 PR の範囲外)。
  scope :before_cursor, ->(cursor) {
    cursor.present? ? where("trips.id < ?", cursor.to_i) : all
  }

  scope :by_tag, ->(name) {
    return all if name.blank?
    joins(:tags).where(tags: { name: name }).distinct
  }

  scope :by_category, ->(value) {
    return all if value.blank?
    where(category: value)
  }

  scope :in_date_range, ->(from, to) {
    rel = all
    rel = rel.where("started_on >= ?", from) if from.present?
    rel = rel.where("ended_on <= ?",   to)   if to.present?
    rel
  }

  # F-SEARCH-01: タイトル/場所/タグ名 の OR 横断検索
  # LIKE のワイルドカード (% / _) は sanitize_sql_like でエスケープし、
  # 値は placeholder で渡す (E-H2 SQLi 対策)。
  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q.to_s)}%"
    left_joins(:tags)
      .where("trips.title LIKE :q OR trips.destination LIKE :q OR tags.name LIKE :q", q: pattern)
      .distinct
  }

  scope :sorted, ->(mode) {
    case mode.to_s
    when "popular" then order(likes_count: :desc, id: :desc)
    when "title"   then order(title: :asc, id: :asc)
    else                order(created_at: :desc, id: :desc)
    end
  }

  def liked_by?(user)
    return false unless user
    likes.exists?(user_id: user.id)
  end

  # フォーム入力 (カンマ区切り文字列 or 配列) を受け、Tag を find_or_create して
  # has_many :tags に同期する。空配列を渡すと全タグを外す。
  def tag_list=(input)
    names =
      if input.is_a?(String)
        input.split(/[,、]/)
      else
        Array(input)
      end
    @tag_list_pending = names
  end

  def tag_list
    tags.map(&:name)
  end

  after_save :sync_tags!

  private

  def sync_tags!
    return if @tag_list_pending.nil?
    new_tags = Tag.find_or_create_by_names(@tag_list_pending)
    self.tags = new_tags
    @tag_list_pending = nil
  end

  def end_after_start
    return if started_on.blank? || ended_on.blank?
    errors.add(:ended_on, "は開始日以降を指定してください") if ended_on < started_on
  end

  def images_count_within_limit
    errors.add(:images, "は最大 5 枚までです") if images.attached? && images.count > 5
  end

  def images_size_within_limit
    return unless images.attached?
    images.each do |img|
      if img.blob.byte_size > 5.megabytes
        errors.add(:images, "の各ファイルは 5MB 以下にしてください")
        break
      end
    end
  end

  # tag_list= 経由でフォーム入力されたタグを、save 前に長さ検証する。
  # Tag.create! が後付けで RecordInvalid を上げると 500 になるため、ここで先回り。
  def tag_list_within_limits
    return if @tag_list_pending.nil?
    cleaned = @tag_list_pending.map { |n| n.to_s.strip }.reject(&:blank?).uniq
    if cleaned.any? { |n| n.length > 32 }
      errors.add(:tags, "は各 32 文字以内にしてください")
    end
  end
end
