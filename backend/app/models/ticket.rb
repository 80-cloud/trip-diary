class Ticket < ApplicationRecord
  KINDS = %w[train hotel flight ticket other].freeze
  MAX_FILE_SIZE = 10.megabytes
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/png image/gif image/webp
    application/pdf
  ].freeze

  belongs_to :trip
  has_one_attached :file

  validates :kind, inclusion: { in: KINDS }
  validates :reservation_no, length: { maximum: 80 }
  validates :url,            length: { maximum: 500 }
  validates :notes,          length: { maximum: 500 }
  validate :file_within_limits
  validate :at_least_one_field

  scope :ordered, -> { order(:position, :id) }

  private

  # チケットは「予約番号 / URL / メモ / ファイル」の少なくとも 1 つを持つ必要がある。
  # 空のチケット (kind だけ) は意味がないので拒否。
  def at_least_one_field
    return if reservation_no.present? || url.present? || notes.present? || file.attached?
    errors.add(:base, "予約番号 / URL / メモ / ファイルの少なくとも 1 つを入力してください")
  end

  def file_within_limits
    return unless file.attached?
    if file.blob.byte_size > MAX_FILE_SIZE
      errors.add(:file, "は 10MB 以下にしてください")
    end
    unless ALLOWED_CONTENT_TYPES.include?(file.blob.content_type)
      errors.add(:file, "は画像 (JPEG/PNG/GIF/WebP) または PDF のみアップロードできます")
    end
  end
end
