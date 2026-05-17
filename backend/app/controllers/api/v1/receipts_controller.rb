module Api
  module V1
    class ReceiptsController < BaseController
      before_action :authenticate_user!
      before_action :set_trip
      before_action :authorize_owner!

      def create
        receipt = @trip.receipts.new(receipt_params)
        if receipt.save
          render json: receipt_payload(receipt), status: :created
        else
          render json: { errors: receipt.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        receipt = @trip.receipts.find(params[:id])
        if receipt.update(receipt_params)
          render json: receipt_payload(receipt)
        else
          render json: { errors: receipt.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @trip.receipts.where(id: params[:id]).delete_all
        head :no_content
      end

      private

      def set_trip
        @trip = Trip.visible_to(current_user).find(params[:trip_id])
      end

      def authorize_owner!
        return if @trip.user_id == current_user.id
        render json: { error: "自分の旅行記録のみレシートを編集できます" }, status: :forbidden
      end

      def receipt_params
        permitted = params.permit(:amount, :category, :description, :spent_on)
        # 不正な category は "other" にサニタイズ (enum 罠回避)
        if permitted[:category].present? && !Receipt::CATEGORIES.include?(permitted[:category])
          permitted[:category] = "other"
        end
        permitted
      end

      def receipt_payload(r)
        {
          id: r.id,
          amount: format("%.2f", r.amount),
          category: r.category,
          description: r.description,
          spent_on: r.spent_on
        }
      end
    end
  end
end
