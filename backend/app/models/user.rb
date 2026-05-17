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

  has_one_attached :avatar

  AVATAR_MAX_SIZE = 2.megabytes
  AVATAR_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true, length: { in: 1..30 }
  validates :bio, length: { maximum: 500 }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validate  :avatar_within_limits

  before_save { self.email = email.downcase.strip }

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

  private

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
