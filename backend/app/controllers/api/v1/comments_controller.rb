module Api
  module V1
    class CommentsController < BaseController
      before_action :authenticate_user!
      before_action :set_trip

      def create
        comment = @trip.comments.new(user: current_user, body: params[:body])
        if comment.save
          render json: comment_payload(comment), status: :created
        else
          render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        comment = @trip.comments.find(params[:id])
        unless comment.user_id == current_user.id
          render json: { error: "自分のコメントのみ削除できます" }, status: :forbidden
          return
        end
        comment.destroy
        head :no_content
      end

      private

      def set_trip
        # 他人の draft / 非公開 trip にコメントを付けられないよう visible_to で絞る。
        # 見えない trip は 404 にすることで「存在の漏洩」も防ぐ。
        @trip = Trip.visible_to(current_user).find(params[:trip_id])
      end

      def comment_payload(c)
        {
          id: c.id, body: c.body, created_at: c.created_at,
          user: { id: c.user.id, display_name: c.user.display_name, email: c.user.email }
        }
      end
    end
  end
end
