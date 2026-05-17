module Api
  module V1
    class TagsController < BaseController
      # GET /api/v1/tags/popular
      # F-TAG-03: 投稿数の多いタグを返す (デフォルト 20 件)
      def popular
        limit = (params[:limit] || 20).to_i.clamp(1, 100)
        tags = Tag.popular(limit)
        render json: tags.map { |t| tag_summary(t) }
      end

      # GET /api/v1/tags/:name
      # F-TAG-02: タグに紐づく Trip 一覧を返す
      def show
        tag = Tag.find_by(name: params[:name])
        unless tag
          render json: { error: "タグが見つかりません" }, status: :not_found
          return
        end

        trips = Trip.visible_to(current_user)
                    .by_tag(tag.name)
                    .sorted(params[:sort])
                    .includes(:user, :tags, images_attachments: :blob)
        liked_ids = current_user ? current_user.likes.where(trip_id: trips.map(&:id)).pluck(:trip_id).to_set : Set.new

        render json: {
          tag: tag_summary(tag),
          trips: trips.map { |t| trip_summary(t, liked_ids: liked_ids) }
        }
      end

      private

      def tag_summary(tag)
        { id: tag.id, name: tag.name, trips_count: tag.trips_count }
      end

      def trip_summary(trip, liked_ids:)
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
          user: { id: trip.user.id, display_name: trip.user.display_name, email: trip.user.email },
          image_url: trip.images.attached? ? Rails.application.routes.url_helpers.rails_blob_path(trip.images.first, only_path: true) : nil,
          created_at: trip.created_at
        }
      end
    end
  end
end
