class Trip < ApplicationRecord
  VISIBILITIES = %w[public friends private].freeze

  belongs_to :user
  has_many :day_entries, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :trip
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :liking_users, through: :likes, source: :user
  has_many_attached :images

  accepts_nested_attributes_for :day_entries, allow_destroy: true, reject_if: :all_blank

  validates :title, presence: true, length: { maximum: 80 }
  validates :destination, presence: true, length: { maximum: 80 }
  validates :started_on, :ended_on, presence: true
  validates :body, length: { maximum: 5000 }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validate :end_after_start
  validate :images_count_within_limit
  validate :images_size_within_limit

  scope :recent, -> { order(created_at: :desc) }
  scope :visible_to, ->(user) {
    if user
      where("visibility = ? OR user_id = ?", "public", user.id)
    else
      where(visibility: "public")
    end
  }

  def liked_by?(user)
    return false unless user
    likes.exists?(user_id: user.id)
  end

  private

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
end
