class RevokedJti < ApplicationRecord
  self.primary_key = :jti

  validates :jti,        presence: true, length: { maximum: 36 }
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }

  # idempotent: 同じ jti を 2 回 revoke しても 1 行だけ (race も DB PK で防ぐ)
  # MySQL は :unique_by 非対応のため upsert (INSERT ... ON DUPLICATE KEY UPDATE) を使う
  def self.revoke!(jti:, expires_at:)
    return if jti.blank? || expires_at.blank?
    upsert({ jti: jti, expires_at: expires_at, created_at: Time.current })
  end

  # 期限切れ行を一括削除 (logout 時に lazy cleanup)
  def self.cleanup_expired!
    where("expires_at <= ?", Time.current).delete_all
  end
end
