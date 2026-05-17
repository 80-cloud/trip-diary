class Notification < ApplicationRecord
  VERBS = %w[commented liked followed].freeze

  belongs_to :recipient, class_name: "User"
  belongs_to :actor,     class_name: "User"
  belongs_to :target,    polymorphic: true

  validates :verb, inclusion: { in: VERBS }
  # 同一 (recipient, actor, verb, target) は 1 件のみ (二重作成防御)
  validates :recipient_id, uniqueness: { scope: [ :actor_id, :verb, :target_type, :target_id ] }
  validate  :actor_must_differ_from_recipient

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def read!
    update!(read_at: Time.current) if read_at.nil?
  end

  private

  def actor_must_differ_from_recipient
    errors.add(:base, "自分自身への通知は作成できません") if recipient_id == actor_id
  end
end
