module Api
  module V1
    class TripsController < BaseController
      before_action :authenticate_user!, only: [:create, :update, :destroy]
      before_action :set_trip, only: [:show, :update, :destroy]
      before_action :authorize_owner!, only: [:update, :destroy]

      def index
        trips = Trip.visible_to(current_user)
                    .recent
                    .includes(:user, images_attachments: :blob)
        liked_ids = current_user ? current_user.likes.where(trip_id: trips.map(&:id)).pluck(:trip_id).to_set : Set.new
        render json: trips.map { |t| trip_summary(t, liked_ids: liked_ids) }
      end

      def show
        liked_ids = current_user && @trip.liked_by?(current_user) ? Set[@trip.id] : Set.new
        render json: trip_detail(@trip, liked_ids: liked_ids)
      end

      def create
        trip = current_user.trips.new(trip_params)
        if trip.save
          render json: trip_detail(trip, liked_ids: Set.new), status: :created
        else
          render json: { errors: trip.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @trip.update(trip_params)
          render json: trip_detail(@trip, liked_ids: Set.new)
        else
          render json: { errors: @trip.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @trip.destroy
        head :no_content
      end

      private

      def set_trip
        @trip = Trip.includes(
          :user,
          :day_entries,
          { comments: :user },
          images_attachments: :blob
        ).find(params[:id])
      end

      def authorize_owner!
        return if @trip.user_id == current_user&.id
        render json: { error: "自分の旅行記録のみ編集・削除できます" }, status: :forbidden
      end

      def trip_params
        params.permit(
          :title, :destination, :started_on, :ended_on, :body, :visibility,
          images: [],
          day_entries_attributes: [:id, :day_number, :happened_on, :title, :body, :position, :_destroy]
        )
      end

      def trip_summary(trip, liked_ids:)
        {
          id: trip.id,
          title: trip.title,
          destination: trip.destination,
          started_on: trip.started_on,
          ended_on: trip.ended_on,
          visibility: trip.visibility,
          likes_count: trip.likes_count,
          comments_count: trip.comments_count,
          liked_by_me: liked_ids.include?(trip.id),
          user: user_payload(trip.user),
          image_url: trip.images.attached? ? rails_blob_path(trip.images.first, only_path: true) : nil,
          created_at: trip.created_at
        }
      end

      def trip_detail(trip, liked_ids:)
        trip_summary(trip, liked_ids: liked_ids).merge(
          body: trip.body,
          day_entries: trip.day_entries.map { |d| day_entry_payload(d) },
          comments: trip.comments.order(:created_at).map { |c| comment_payload(c) },
          image_urls: trip.images.attached? ? trip.images.map { |i| rails_blob_path(i, only_path: true) } : []
        )
      end

      def day_entry_payload(d)
        { id: d.id, day_number: d.day_number, happened_on: d.happened_on, title: d.title, body: d.body, position: d.position }
      end

      def comment_payload(c)
        { id: c.id, body: c.body, created_at: c.created_at, user: user_payload(c.user) }
      end

      def user_payload(user)
        { id: user.id, display_name: user.display_name, email: user.email }
      end

      def rails_blob_path(attachment, **opts)
        Rails.application.routes.url_helpers.rails_blob_path(attachment, **opts)
      end
    end
  end
end
