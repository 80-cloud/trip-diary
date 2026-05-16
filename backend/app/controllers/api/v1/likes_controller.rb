module Api
  module V1
    class LikesController < BaseController
      before_action :authenticate_user!
      before_action :set_trip

      def create
        like = @trip.likes.find_or_initialize_by(user: current_user)
        if like.persisted? || like.save
          render json: { liked: true, likes_count: @trip.reload.likes_count }, status: :created
        else
          render json: { errors: like.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        like = @trip.likes.find_by(user: current_user)
        like&.destroy
        render json: { liked: false, likes_count: @trip.reload.likes_count }
      end

      private

      def set_trip
        @trip = Trip.find(params[:trip_id])
      end
    end
  end
end
