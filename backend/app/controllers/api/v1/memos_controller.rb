module Api
  module V1
    class MemosController < BaseController
      before_action :authenticate_user!
      before_action :set_trip

      # PUT /api/v1/trips/:trip_id/memo
      # F-MEMO-01: 本人専用メモを保存 (find_or_initialize で upsert)
      # body が空なら削除 (=「メモを消す」UX)。
      def update
        body_param = params[:body].to_s.strip
        if body_param.empty?
          current_user.memos.where(trip_id: @trip.id).delete_all
          render json: { memo: nil }
          return
        end

        memo = current_user.memos.find_or_initialize_by(trip_id: @trip.id)
        memo.body = body_param
        if memo.save
          render json: { memo: memo.body }
        else
          render json: { errors: memo.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/trips/:trip_id/memo (冪等)
      def destroy
        current_user.memos.where(trip_id: @trip.id).delete_all
        render json: { memo: nil }
      end

      private

      def set_trip
        # 他人の draft / 非公開 trip にはメモを残せない (見えない trip にメモする意味がない + 存在の漏洩を防ぐ)
        @trip = Trip.visible_to(current_user).find(params[:trip_id])
      end
    end
  end
end
