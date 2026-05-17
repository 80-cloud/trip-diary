module Api
  module V1
    class ReviewsController < BaseController
      before_action :authenticate_user!
      before_action :set_trip
      before_action :authorize_owner!

      # PUT /api/v1/trips/:trip_id/review (upsert)
      # 1 trip 1 review なので create も update もこの単一エンドポイントで処理。
      def update
        review = @trip.review || @trip.build_review
        review.assign_attributes(review_params)
        if review.save
          render json: review_payload(review)
        elsif review.errors.added?(:trip_id, :taken)
          # race: 別リクエストが先に insert → reload して update に倒す
          retry_as_update
        else
          render json: { errors: review.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        retry_as_update
      end

      def destroy
        @trip.review&.destroy
        head :no_content
      end

      private

      def set_trip
        @trip = Trip.visible_to(current_user).find(params[:trip_id])
      end

      def authorize_owner!
        return if @trip.user_id == current_user.id
        render json: { error: "自分の旅行記録のみレビューを編集できます" }, status: :forbidden
      end

      def review_params
        params.permit(:rating, :body)
      end

      def retry_as_update
        existing = @trip.reload.review
        if existing&.update(review_params)
          render json: review_payload(existing)
        else
          render json: { errors: existing&.errors&.full_messages || [ "保存に失敗しました" ] },
                 status: :unprocessable_entity
        end
      end

      def review_payload(r)
        { id: r.id, rating: r.rating, body: r.body, created_at: r.created_at, updated_at: r.updated_at }
      end
    end
  end
end
