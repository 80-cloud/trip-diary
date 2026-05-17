module Api
  module V1
    class NotificationsController < BaseController
      before_action :authenticate_user!

      INDEX_LIMIT = 50

      # GET /api/v1/notifications
      # 自分宛の通知を新しい順に最新 50 件返す。
      # MVP: cursor pagination は実装しない (PR-C ドロップダウンで 50 件表示で十分)。
      def index
        notifications = current_user.notifications
                                    .recent
                                    .limit(INDEX_LIMIT)
                                    .preload(:actor, :target)
        render json: {
          notifications: notifications.map { |n| serialize(n) },
          unread_count:  current_user.notifications.unread.count
        }
      end

      # GET /api/v1/notifications/unread_count
      def unread_count
        render json: { unread_count: current_user.notifications.unread.count }
      end

      # PATCH /api/v1/notifications/:id
      # 個別既読化。他人宛の通知へのアクセスは存在性を漏らさないため 404。
      # current_user.notifications.find(...) を通すことで自動的に 404。
      def update
        notification = current_user.notifications.find(params[:id])
        notification.read!
        render json: serialize(notification)
      end

      # POST /api/v1/notifications/read_all
      # 自分の未読通知を全て既読化。冪等。
      def read_all
        now = Time.current
        affected = current_user.notifications.unread.update_all(read_at: now, updated_at: now)
        render json: { read_count: affected, unread_count: 0 }
      end

      private

      def serialize(notification)
        data = {
          id:          notification.id,
          verb:        notification.verb,
          target_type: notification.target_type,
          target_id:   notification.target_id,
          read_at:     notification.read_at,
          created_at:  notification.created_at,
          actor: {
            id:           notification.actor.id,
            display_name: notification.actor.display_name
          }
        }
        # Comment / Like の通知は遷移先 trip の id を含める。
        # target が destroy 済 (孤児) の場合は nil。
        if notification.target.respond_to?(:trip_id)
          data[:trip_id] = notification.target.trip_id
        end
        data
      end
    end
  end
end
