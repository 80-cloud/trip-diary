class Like < ApplicationRecord
  belongs_to :trip, counter_cache: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: :trip_id }

  after_commit :create_notification, on: :create

  private

  # F-NOTIF-01: trip 所有者にいいね受信通知
  def create_notification
    recipient_id = trip.user_id
    return if recipient_id == user_id

    Notification.create!(
      recipient_id: recipient_id,
      actor_id: user_id,
      verb: "liked",
      target: self
    )
  rescue ActiveRecord::RecordInvalid
  end
end
