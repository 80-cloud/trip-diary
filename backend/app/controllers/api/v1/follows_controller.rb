module Api
  module V1
    class FollowsController < BaseController
      before_action :authenticate_user!, only: [ :create, :destroy ]
      before_action :set_target_user

      # POST /api/v1/users/:user_id/follow
      # F-FOLLOW-01: 冪等 (既存→200 / 新規→201)。自己フォローは 422。
      def create
        if @target.id == current_user.id
          return render(json: { errors: [ "自分自身をフォローできません" ] }, status: :unprocessable_entity)
        end

        follow = current_user.active_follows.find_or_initialize_by(followed_id: @target.id)
        if follow.persisted?
          render json: { following: true }, status: :ok
        else
          begin
            follow.save!
            render json: { following: true }, status: :created
          rescue ActiveRecord::RecordNotUnique
            render json: { following: true }, status: :ok
          rescue ActiveRecord::RecordInvalid => e
            if e.record.errors.added?(:follower_id, :taken)
              render json: { following: true }, status: :ok
            else
              raise
            end
          end
        end
      end

      # DELETE /api/v1/users/:user_id/follow (冪等)
      def destroy
        current_user.active_follows.where(followed_id: @target.id).delete_all
        render json: { following: false }
      end

      # GET /api/v1/users/:user_id/follows?type=following|followers
      # F-FOLLOW-03: 公開ビュー (未ログインでも閲覧可)
      def index
        list =
          case params[:type].to_s
          when "followers" then @target.followers
          else                  @target.followings   # デフォルトは following
          end
        render json: list.order(:id).map { |u| user_summary(u) }
      end

      private

      def set_target_user
        @target = User.find(params[:user_id])
      end

      def user_summary(u)
        {
          id: u.id,
          display_name: u.display_name,
          email: u.email,
          followed_by_me: current_user ? current_user.following?(u) : false
        }
      end
    end
  end
end
