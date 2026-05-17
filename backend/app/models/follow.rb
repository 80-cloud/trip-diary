class Follow < ApplicationRecord
  belongs_to :follower, class_name: "User"
  belongs_to :followed, class_name: "User"

  validates :follower_id, uniqueness: { scope: :followed_id }
  validate :cannot_follow_self

  after_commit :create_notification, on: :create

  private

  def cannot_follow_self
    errors.add(:base, "自分自身をフォローできません") if follower_id == followed_id
  end

  # F-NOTIF-01: followed ユーザーにフォロー受信通知
  def create_notification
    return if follower_id == followed_id  # validation で弾かれるが念のため

    Notification.create!(
      recipient_id: followed_id,
      actor_id: follower_id,
      verb: "followed",
      target: self
    )
  rescue ActiveRecord::RecordInvalid
  end
end
