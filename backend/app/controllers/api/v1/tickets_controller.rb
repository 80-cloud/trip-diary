module Api
  module V1
    class TicketsController < BaseController
      before_action :authenticate_user!
      before_action :set_trip
      before_action :authorize_owner!

      def create
        ticket = @trip.tickets.new(ticket_params)
        ticket.position = (@trip.tickets.maximum(:position) || 0) + 1 if ticket.position.zero?
        if ticket.save
          render json: ticket_payload(ticket), status: :created
        else
          render json: { errors: ticket.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        ticket = @trip.tickets.find(params[:id])
        if ticket.update(ticket_params)
          render json: ticket_payload(ticket)
        else
          render json: { errors: ticket.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @trip.tickets.where(id: params[:id]).delete_all
        head :no_content
      end

      private

      def set_trip
        @trip = Trip.visible_to(current_user).find(params[:trip_id])
      end

      def authorize_owner!
        return if @trip.user_id == current_user.id
        render json: { error: "自分の旅行記録のみチケットを編集できます" }, status: :forbidden
      end

      def ticket_params
        permitted = params.permit(:kind, :reservation_no, :url, :notes, :position, :file)
        # 不正な kind は "other" にサニタイズ (enum 不在の string カラム + inclusion validation だが、
        # blank だと validation で 422 → 正しく動くので nil/空はそのまま)
        if permitted[:kind].present? && !Ticket::KINDS.include?(permitted[:kind])
          permitted[:kind] = "other"
        end
        permitted
      end

      def ticket_payload(t)
        {
          id: t.id,
          kind: t.kind,
          reservation_no: t.reservation_no,
          url: t.url,
          notes: t.notes,
          position: t.position,
          file_url: t.file.attached? ? Rails.application.routes.url_helpers.rails_blob_path(t.file, only_path: true) : nil
        }
      end
    end
  end
end
