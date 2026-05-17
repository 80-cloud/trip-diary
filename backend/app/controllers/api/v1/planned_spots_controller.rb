module Api
  module V1
    class PlannedSpotsController < BaseController
      before_action :authenticate_user!
      before_action :set_trip
      before_action :authorize_owner!

      # POST /api/v1/trips/:trip_id/planned_spots
      def create
        spot = @trip.planned_spots.new(spot_params)
        spot.position = (@trip.planned_spots.maximum(:position) || 0) + 1 if spot.position.zero?
        if spot.save
          render json: spot_payload(spot), status: :created
        else
          render json: { errors: spot.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/trips/:trip_id/planned_spots/:id
      def update
        spot = @trip.planned_spots.find(params[:id])
        if spot.update(spot_params)
          render json: spot_payload(spot)
        else
          render json: { errors: spot.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/trips/:trip_id/planned_spots/:id
      def destroy
        @trip.planned_spots.where(id: params[:id]).delete_all
        head :no_content
      end

      private

      def set_trip
        # planned_spots は本人専用機能。visible_to で 404 した上で authorize_owner で再確認。
        @trip = Trip.visible_to(current_user).find(params[:trip_id])
      end

      def authorize_owner!
        return if @trip.user_id == current_user.id
        render json: { error: "自分の旅行記録のみ計画を編集できます" }, status: :forbidden
      end

      def spot_params
        params.permit(:title, :done, :position)
      end

      def spot_payload(spot)
        {
          id: spot.id,
          title: spot.title,
          done: spot.done,
          position: spot.position,
          day_entry_id: spot.day_entry_id
        }
      end
    end
  end
end
