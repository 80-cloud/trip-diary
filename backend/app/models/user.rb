class User < ApplicationRecord
  has_secure_password

  has_many :trips, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :liked_trips, through: :likes, source: :trip
  has_many :favorites, dependent: :destroy
  has_many :favorite_trips, through: :favorites, source: :trip
  has_many :memos, dependent: :destroy

  # 自己参照フォロー関連 (follower → followed):
  # - active_follows: 自分がフォローしている関係 (follower=self)
  # - passive_follows: 自分がフォローされている関係 (followed=self)
  has_many :active_follows,  class_name: "Follow", foreign_key: :follower_id, dependent: :destroy
  has_many :passive_follows, class_name: "Follow", foreign_key: :followed_id, dependent: :destroy
  has_many :followings, through: :active_follows,  source: :followed
  has_many :followers,  through: :passive_follows, source: :follower

  # 通知 (F-NOTIF-01): recipient=自分宛 / actor=自分が引き金になった通知
  has_many :notifications,           foreign_key: :recipient_id, dependent: :destroy
  has_many :triggered_notifications, class_name: "Notification", foreign_key: :actor_id, dependent: :destroy

  has_one_attached :avatar

  AVATAR_MAX_SIZE = 2.megabytes
  AVATAR_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  # F-GUEST-01: 訪問者ごとの一時ゲスト (docs/公開デモ化計画書.md §5)
  GUEST_TTL = 24.hours # JWT / Cookie の有効期限 (1 日) と同じ
  GUEST_MAX_ACTIVE = 200
  GUEST_CLEANUP_BATCH = 20
  # .invalid は実在しないことが保証されたドメイン (RFC 2606)。実在の人にメールが届かない
  GUEST_EMAIL_DOMAIN = "example.invalid".freeze
  # デモユーザー (demo:seed で作る・誰もログインできない) の見分け方
  DEMO_EMAIL_DOMAIN = "demo.example.com".freeze
  # 保存容量の無料枠を守るため、ゲストの画像は旅行の画像・チケット・アバターの合計で数える
  GUEST_IMAGE_LIMIT = 5
  GUEST_IMAGE_LIMIT_ERROR = "ゲストが保存できる画像は、旅行の画像・チケット・アバターを合わせて #{GUEST_IMAGE_LIMIT} 枚までです".freeze

  scope :guests,         -> { where(guest: true) }
  scope :active_guests,  -> { guests.where("users.created_at > ?", GUEST_TTL.ago) }
  scope :expired_guests, -> { guests.where("users.created_at <= ?", GUEST_TTL.ago) }
  scope :demo_users,     -> { where("users.email LIKE ?", "%@#{DEMO_EMAIL_DOMAIN}").order(:id) }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true, length: { in: 1..30 }
  validates :bio, length: { maximum: 500 }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validate  :avatar_within_limits
  validate  :guest_image_total_within_limit

  before_save { self.email = email.downcase.strip }

  # パスワードは乱数で作って捨てる (利用者には返さない = メールアドレスでのログインはできない)
  def self.create_guest!
    create!(
      guest: true,
      email: "guest-#{SecureRandom.hex(12)}@#{GUEST_EMAIL_DOMAIN}",
      password: SecureRandom.base58(32),
      display_name: format("ゲスト-%04d", SecureRandom.random_number(10_000))
    )
  end

  # 期限切れのゲストを destroy で削除し、削除できた人数を返す。
  # SQL 直の DELETE は dependent: :destroy が動かず孤立レコードが残るため使わない (CLAUDE.md §6)。
  # 呼び出したリクエストの応答を遅らせないよう、1 回の人数を絞る。
  def self.cleanup_expired_guests!(limit: GUEST_CLEANUP_BATCH)
    expired_guests.order(:id).limit(limit).to_a.count(&:destroy)
  end

  # other を相互フォローしている (= 双方が follow 関係) か判定。friends 可視性で使用。
  def mutual_follow?(other)
    return false unless other
    active_follows.exists?(followed_id: other.id) &&
      passive_follows.exists?(follower_id: other.id)
  end

  def following?(other)
    return false unless other
    active_follows.exists?(followed_id: other.id)
  end

  # ゲストの画像の合計が上限を超えるなら、検査中の記録 (record) にエラーを足す。
  # record の分は保存予定の数 (pending) で数え、ほかの記録は DB の数で数える。
  # pending が 0 なら合計は増えないので数えない。
  def validate_guest_image_limit(record, pending)
    return unless guest? && pending.positive?
    return if saved_image_count_except(record) + pending <= GUEST_IMAGE_LIMIT
    record.errors.add(:base, GUEST_IMAGE_LIMIT_ERROR)
  end

  private

  def guest_image_total_within_limit
    validate_guest_image_limit(self, avatar.attached? ? 1 : 0)
  end

  # 旅行の画像・チケットのファイル・アバターのうち、record 以外の保存済みの数 (1 クエリ)
  def saved_image_count_except(record)
    attachments = ActiveStorage::Attachment
    trip_ids = trips.select(:id)
    attachments.where(record_type: "Trip", name: "images", record_id: trip_ids)
               .or(attachments.where(record_type: "Ticket", name: "file", record_id: Ticket.where(trip_id: trip_ids).select(:id)))
               .or(attachments.where(record_type: "User", name: "avatar", record_id: id))
               .where.not(record_type: record.class.name, record_id: record.id)
               .count
  end

  def avatar_within_limits
    return unless avatar.attached?
    if avatar.blob.byte_size > AVATAR_MAX_SIZE
      errors.add(:avatar, "は 2MB 以下にしてください")
    end
    unless AVATAR_CONTENT_TYPES.include?(avatar.blob.content_type)
      errors.add(:avatar, "は JPEG / PNG / GIF / WebP 画像のみアップロードできます")
    end
  end
end
