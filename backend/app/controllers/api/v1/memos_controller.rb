module Api
  module V1
    class MemosController < BaseController
      before_action :authenticate_user!
      before_action :set_trip

      # PUT /api/v1/trips/:trip_id/memo
      # F-MEMO-01: 本人専用メモを upsert で保存。
      # body が空なら削除 (=「メモを消す」UX)。
      # 並行 race (別タブ同時保存) でも 500 にならないよう validation/DB の両 race を rescue
      # して既存レコードの update に倒す (upsert semantics)。
      def update
        body_param = params[:body].to_s.strip
        if body_param.empty?
          current_user.memos.where(trip_id: @trip.id).delete_all
          return render(json: { memo: nil })
        end

        memo = current_user.memos.find_or_initialize_by(trip_id: @trip.id)
        memo.body = body_param

        if memo.save
          render json: { memo: memo.body }
        elsif memo.errors.added?(:user_id, :taken)
          # validation-level race: find_or_initialize_by の後で別リクエストが先に INSERT した
          retry_as_update(body_param)
        else
          render json: { errors: memo.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        # DB-level race: validation 通過後の INSERT で unique index に弾かれた
        retry_as_update(body_param)
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

      def retry_as_update(body_param)
        existing = current_user.memos.find_by(trip_id: @trip.id)
        if existing&.update(body: body_param)
          render json: { memo: existing.body }
        else
          render json: { errors: existing&.errors&.full_messages || [ "保存に失敗しました" ] },
                 status: :unprocessable_entity
        end
      end
    end
  end
end
