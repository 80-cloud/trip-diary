module Api
  module V1
    class FavoritesController < BaseController
      before_action :authenticate_user!
      # set_trip は :create / :destroy のみ。:index は trip に依存しないため
      before_action :set_trip, only: [:create, :destroy]

      # GET /api/v1/favorites
      # F-FAV-01: 自分のお気に入り trip 一覧 (新しい順)
      def index
        # お気に入りした trip も visible_to で再フィルタ
        # (お気に入りした後に投稿者が private に切替したケースなどでも漏らさない)
        favorited_trip_ids = current_user.favorites.order(created_at: :desc).pluck(:trip_id)
        trips = Trip.visible_to(current_user)
                    .where(id: favorited_trip_ids)
                    .includes(:user, :tags, images_attachments: :blob)
        # 元の順序 (お気に入り登録順) を維持するため Ruby 側で並び替え
        trip_map = trips.index_by(&:id)
        ordered = favorited_trip_ids.map { |id| trip_map[id] }.compact
        liked_ids = current_user.likes.where(trip_id: ordered.map(&:id)).pluck(:trip_id).to_set
        favorited_ids = favorited_trip_ids.to_set
        render json: ordered.map { |t| trip_summary(t, liked_ids: liked_ids, favorited_ids: favorited_ids) }
      end

      # PUT /api/v1/trips/:trip_id/favorite (冪等: 既存ならそのまま 200, なければ 201)
      def create
        fav = current_user.favorites.find_or_initialize_by(trip_id: @trip.id)
        if fav.persisted?
          render json: { favorited: true }, status: :ok
        else
          begin
            fav.save!
            render json: { favorited: true }, status: :created
          rescue ActiveRecord::RecordNotUnique
            # 並行リクエスト race: validation 後に他リクエストが先に insert → unique 違反
            # → すでに目的を達したのと同等なので 200 で返す (冪等性維持)
            render json: { favorited: true }, status: :ok
          end
        end
      end

      # DELETE /api/v1/trips/:trip_id/favorite (冪等: 無くても 200)
      def destroy
        current_user.favorites.where(trip_id: @trip.id).delete_all
        render json: { favorited: false }
      end

      private

      def set_trip
        # 他人の draft / 非公開 trip をお気に入りできないよう visible_to で守る
        @trip = Trip.visible_to(current_user).find(params[:trip_id])
      end

      def trip_summary(trip, liked_ids:, favorited_ids:)
        {
          id: trip.id,
          title: trip.title,
          destination: trip.destination,
          started_on: trip.started_on,
          ended_on: trip.ended_on,
          category: trip.category,
          tags: trip.tags.map(&:name),
          likes_count: trip.likes_count,
          comments_count: trip.comments_count,
          liked_by_me: liked_ids.include?(trip.id),
          favorited_by_me: favorited_ids.include?(trip.id),
          user: { id: trip.user.id, display_name: trip.user.display_name, email: trip.user.email },
          image_url: trip.images.attached? ? Rails.application.routes.url_helpers.rails_blob_path(trip.images.first, only_path: true) : nil,
          created_at: trip.created_at
        }
      end
    end
  end
end
