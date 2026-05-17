module Api
  module V1
    class TripsController < BaseController
      before_action :authenticate_user!, only: [:create, :update, :destroy]
      before_action :set_trip, only: [:show, :update, :destroy]
      before_action :authorize_owner!, only: [:update, :destroy]

      DEFAULT_PAGE_LIMIT = 20
      MAX_PAGE_LIMIT     = 50

      def index
        # ?mine=drafts は本人専用ビュー。未ログイン or 他人は空配列で返す
        # (404 等で「存在しない」を漏らさないよう、空配列で揃える)
        if params[:mine] == "drafts"
          return render(json: { trips: [], next_cursor: nil }) unless current_user
          base = current_user.trips.draft
        elsif params[:mine] == "following"
          # F-FOLLOW-04: 自分がフォローしているユーザーの公開 trip のみ
          return render(json: { trips: [], next_cursor: nil }) unless current_user
          following_ids = current_user.followings.pluck(:id)
          base = Trip.visible_to(current_user).where(user_id: following_ids)
        else
          base = Trip.visible_to(current_user)
                     .by_tag(params[:tag])
                     .by_category(params[:category])
                     .in_date_range(params[:date_from], params[:date_to])
                     .search(params[:q])
          base = base.where(user_id: params[:user_id]) if params[:user_id].present?
        end

        # cursor pagination は sort=recent (デフォルト) のみ。popular/title は
        # created_at と無関係な順序なので cursor では適用できない (offset は本 PR 範囲外)。
        sort_mode  = params[:sort].to_s
        use_cursor = sort_mode.empty? || sort_mode == "recent"
        limit      = (params[:limit] || DEFAULT_PAGE_LIMIT).to_i.clamp(1, MAX_PAGE_LIMIT)

        trips = base.sorted(sort_mode).includes(:user, :tags, images_attachments: :blob)
        trips = trips.before_cursor(params[:cursor]).limit(limit) if use_cursor

        results = trips.to_a
        next_cursor = (use_cursor && results.size == limit) ? results.last.id : nil

        ids = results.map(&:id)
        liked_ids     = current_user ? current_user.likes.where(trip_id: ids).pluck(:trip_id).to_set : Set.new
        favorited_ids = current_user ? current_user.favorites.where(trip_id: ids).pluck(:trip_id).to_set : Set.new
        # N+1 防止: 各 trip の投稿者についての followed_by_me を 1 クエリで先取り
        author_ids = results.map(&:user_id).uniq
        followed_user_ids = current_user ? current_user.followings.where(id: author_ids).pluck(:id).to_set : Set.new
        render json: {
          trips: results.map { |t| trip_summary(t, liked_ids: liked_ids, favorited_ids: favorited_ids, followed_user_ids: followed_user_ids) },
          next_cursor: next_cursor
        }
      end

      def show
        liked_ids     = current_user && @trip.liked_by?(current_user) ? Set[@trip.id] : Set.new
        favorited_ids = current_user && current_user.favorites.exists?(trip_id: @trip.id) ? Set[@trip.id] : Set.new
        my_memo       = current_user&.memos&.find_by(trip_id: @trip.id)&.body
        # N+1 防止: 投稿者 + 全コメント投稿者の followed_by_me を 1 クエリで先取り
        related_user_ids = ([@trip.user_id] + @trip.comments.map(&:user_id)).uniq
        followed_user_ids = current_user ? current_user.followings.where(id: related_user_ids).pluck(:id).to_set : Set.new
        render json: trip_detail(@trip, liked_ids: liked_ids, favorited_ids: favorited_ids, my_memo: my_memo, followed_user_ids: followed_user_ids)
      end

      def create
        trip = current_user.trips.new(trip_params)
        if trip.save
          render json: trip_detail(trip, liked_ids: Set.new, favorited_ids: Set.new, my_memo: nil, followed_user_ids: Set.new), status: :created
        else
          render json: { errors: trip.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @trip.update(trip_params)
          render json: trip_detail(@trip, liked_ids: Set.new, favorited_ids: Set.new, my_memo: nil, followed_user_ids: Set.new)
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
        # show は visible_to で絞る (draft / 他人 private は 404)。
        # update / destroy は authorize_owner! で別途守るため、全件から find する
        # (本人が自分の draft を編集できる必要があるため visible_to を使えない)。
        scope = action_name == "show" ? Trip.visible_to(current_user) : Trip
        @trip = scope.includes(
          :user,
          :tags,
          :day_entries,
          :planned_spots,
          :packing_items,
          :review,
          { tickets: { file_attachment: :blob } },
          { comments: :user },
          images_attachments: :blob
        ).find(params[:id])
      end

      def authorize_owner!
        return if @trip.user_id == current_user&.id
        render json: { error: "自分の旅行記録のみ編集・削除できます" }, status: :forbidden
      end

      def trip_params
        permitted = params.permit(
          :title, :destination, :started_on, :ended_on, :body, :visibility, :category, :status,
          images: [],
          tag_list: [],
          day_entries_attributes: [:id, :day_number, :happened_on, :title, :body, :position, :_destroy]
        )
        # 未知の category 値は nil に倒す。enum setter は不正値で ArgumentError を raise し、
        # そのままだと 500 になるため。nil にしておけば presence: true で 422 を返せる。
        if permitted[:category].present? && !Trip.categories.key?(permitted[:category])
          permitted[:category] = nil
        end
        # status は不正値だと enum ArgumentError → 500 になるので同様にサニタイズ。
        # 不正値は "published" にフォールバック (UI に存在しない値はバグなので安全側に倒す)。
        if permitted[:status].present? && !Trip.statuses.key?(permitted[:status])
          permitted[:status] = "published"
        end
        permitted
      end

      def trip_summary(trip, liked_ids:, favorited_ids: Set.new, followed_user_ids: Set.new)
        {
          id: trip.id,
          title: trip.title,
          destination: trip.destination,
          started_on: trip.started_on,
          ended_on: trip.ended_on,
          visibility: trip.visibility,
          category: trip.category,
          status: trip.status,
          tags: trip.tags.map(&:name),
          likes_count: trip.likes_count,
          comments_count: trip.comments_count,
          liked_by_me: liked_ids.include?(trip.id),
          favorited_by_me: favorited_ids.include?(trip.id),
          user: user_payload(trip.user, followed_user_ids: followed_user_ids),
          image_url: trip.images.attached? ? rails_blob_path(trip.images.first, only_path: true) : nil,
          created_at: trip.created_at
        }
      end

      def trip_detail(trip, liked_ids:, favorited_ids: Set.new, my_memo: nil, followed_user_ids: Set.new)
        is_owner = current_user && trip.user_id == current_user.id
        # 計画/持ち物/チケットの中身は本人のみ閲覧 (進捗バー値や review は公開情報)
        # has_many 側で order 済 → そのまま使う (N+1 防止)
        planned_spots = is_owner ? trip.planned_spots.map { |s| planned_spot_payload(s) } : []
        packing_items = is_owner ? trip.packing_items.map { |i| packing_item_payload(i) } : []
        tickets       = is_owner ? trip.tickets.map       { |t| ticket_payload(t)        } : []
        trip_summary(trip, liked_ids: liked_ids, favorited_ids: favorited_ids, followed_user_ids: followed_user_ids).merge(
          body: trip.body,
          my_memo: my_memo,
          day_entries: trip.day_entries.map { |d| day_entry_payload(d) },
          comments: trip.comments.order(:created_at).map { |c| comment_payload(c, followed_user_ids: followed_user_ids) },
          image_urls: trip.images.attached? ? trip.images.map { |i| rails_blob_path(i, only_path: true) } : [],
          planned_count: trip.planned_spots.size,
          planned_done_count: trip.planned_spots.count { |s| s.done },
          planned_spots: planned_spots,
          packing_items: packing_items,
          tickets: tickets,
          review: trip.review ? review_payload(trip.review) : nil
        )
      end

      def planned_spot_payload(s)
        { id: s.id, title: s.title, done: s.done, position: s.position, day_entry_id: s.day_entry_id }
      end

      def packing_item_payload(i)
        { id: i.id, body: i.body, packed: i.packed, position: i.position }
      end

      def ticket_payload(t)
        {
          id: t.id, kind: t.kind, reservation_no: t.reservation_no, url: t.url, notes: t.notes,
          position: t.position,
          file_url: t.file.attached? ? rails_blob_path(t.file, only_path: true) : nil
        }
      end

      def review_payload(r)
        { id: r.id, rating: r.rating, body: r.body, updated_at: r.updated_at }
      end

      def day_entry_payload(d)
        { id: d.id, day_number: d.day_number, happened_on: d.happened_on, title: d.title, body: d.body, position: d.position }
      end

      def comment_payload(c, followed_user_ids: Set.new)
        { id: c.id, body: c.body, created_at: c.created_at, user: user_payload(c.user, followed_user_ids: followed_user_ids) }
      end

      def user_payload(user, followed_user_ids: Set.new)
        {
          id: user.id,
          display_name: user.display_name,
          email: user.email,
          followed_by_me: followed_user_ids.include?(user.id)
        }
      end

      def rails_blob_path(attachment, **opts)
        Rails.application.routes.url_helpers.rails_blob_path(attachment, **opts)
      end
    end
  end
end
