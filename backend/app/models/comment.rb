class Comment < ApplicationRecord
  belongs_to :trip, counter_cache: true
  belongs_to :user

  validates :body, presence: true, length: { maximum: 140 }

  after_commit :create_notification, on: :create

  private

  # F-NOTIF-01: trip 所有者にコメント受信通知
  def create_notification
    recipient_id = trip.user_id
    return if recipient_id == user_id

    Notification.create!(
      recipient_id: recipient_id,
      actor_id: user_id,
      verb: "commented",
      target: self
    )
  rescue ActiveRecord::RecordInvalid
    # 重複防御 (uniqueness) で弾かれた場合は無視。本体の Comment は残す。
  end
end
