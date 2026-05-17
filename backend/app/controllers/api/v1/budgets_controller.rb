module Api
  module V1
    class BudgetsController < BaseController
      before_action :authenticate_user!
      before_action :set_trip
      before_action :authorize_owner!

      # PUT /api/v1/trips/:trip_id/budget — upsert (1 trip 1 budget)
      def update
        budget = @trip.budget || @trip.build_budget
        if budget.update(budget_params)
          render json: budget_payload(budget)
        else
          render json: { errors: budget.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        # race: 同時 2 リクエストで両方が build_budget → 後発を 422 に変換 (500 回避)
        render json: { errors: ["既に予算が登録されています"] }, status: :unprocessable_entity
      end

      def destroy
        @trip.budget&.destroy
        head :no_content
      end

      private

      def set_trip
        @trip = Trip.visible_to(current_user).find(params[:trip_id])
      end

      def authorize_owner!
        return if @trip.user_id == current_user.id
        render json: { error: "自分の旅行記録のみ予算を編集できます" }, status: :forbidden
      end

      def budget_params
        permitted = params.permit(:planned_amount, :currency)
        # 不正な currency は "JPY" にサニタイズ (Ticket kind の教訓と同パターン)
        if permitted[:currency].present? && !Budget::CURRENCIES.include?(permitted[:currency])
          permitted[:currency] = "JPY"
        end
        permitted
      end

      def budget_payload(b)
        { id: b.id, planned_amount: format("%.2f", b.planned_amount), currency: b.currency }
      end
    end
  end
end
