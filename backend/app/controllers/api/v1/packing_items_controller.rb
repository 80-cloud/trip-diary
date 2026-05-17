module Api
  module V1
    class PackingItemsController < BaseController
      before_action :authenticate_user!
      before_action :set_trip
      before_action :authorize_owner!

      def create
        item = @trip.packing_items.new(item_params)
        item.position = (@trip.packing_items.maximum(:position) || 0) + 1 if item.position.zero?
        if item.save
          render json: item_payload(item), status: :created
        else
          render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        item = @trip.packing_items.find(params[:id])
        if item.update(item_params)
          render json: item_payload(item)
        else
          render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @trip.packing_items.where(id: params[:id]).delete_all
        head :no_content
      end

      private

      def set_trip
        @trip = Trip.visible_to(current_user).find(params[:trip_id])
      end

      def authorize_owner!
        return if @trip.user_id == current_user.id
        render json: { error: "自分の旅行記録のみ持ち物を編集できます" }, status: :forbidden
      end

      def item_params
        params.permit(:body, :packed, :position)
      end

      def item_payload(item)
        {
          id: item.id,
          body: item.body,
          packed: item.packed,
          position: item.position
        }
      end
    end
  end
end
