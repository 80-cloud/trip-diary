module Api
  module V1
    class AuthController < BaseController
      # E-H2 対策 (docs/セキュリティ自己監査.md §3): email 不在時にもダミー bcrypt を
      # 実行し、応答時間差から email 存在性が漏れることを防ぐ。
      # cost は **fixture (test) と production の user password_digest と一致** させる必要
      # がある (一致しないと不在 email と存在 email で bcrypt 計算量が変わり、本対策の
      # 意味がなくなる)。
      #   - production: BCrypt::Engine.cost (デフォルト 12)
      #   - test: fixtures/users.yml と同じ MIN_COST (4)
      DUMMY_DIGEST_COST = Rails.env.test? ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
      DUMMY_DIGEST = BCrypt::Password.create("dummy", cost: DUMMY_DIGEST_COST).to_s.freeze

      # E-H1 対策 (docs/セキュリティ自己監査.md §3): signup 失敗時はフィールド名を
      # 漏らさない汎用メッセージで統一する (email 列挙防止)。
      GENERIC_SIGNUP_ERROR = "入力内容に誤りがあります。各項目をご確認ください".freeze

      # P0-9: 公開環境ではサインアップを止める (SIGNUP_ENABLED=false)。理由の詳細は返さない
      SIGNUP_DISABLED_ERROR = "現在、新規登録は受け付けていません".freeze

      # F-GUEST-01: 有効なゲストが上限に達したときのメッセージ
      GUEST_BUSY_ERROR = "現在混み合っています。しばらくしてから再試行してください".freeze
      # 初回通知のためにゲストをフォローするデモユーザーの人数
      DEMO_FOLLOWERS_FOR_GUEST = 2

      def signup
        return render(json: { error: SIGNUP_DISABLED_ERROR }, status: :forbidden) unless signup_enabled?

        user = User.new(signup_params)
        if user.save
          issue_jwt_cookie(user)
          render json: { user: user_payload(user) }, status: :created
        else
          # フィールド別の詳細はサーバ内部ログにのみ残す (運用調査用)。
          # `errors.details` をそのまま inspect すると :value キーに入力値 (email 平文) が
          # 含まれ PII が漏れる ため、:value を除外して :error キー (種別) のみ記録する。
          # (E-H1 fix の意図はサーバログを含む全経路で field-level 漏洩を防ぐこと)
          masked_errors = user.errors.details.transform_values { |arr|
            arr.map { |h| h.except(:value) }
          }
          Rails.logger.info("[signup][422] errors=#{masked_errors.inspect}")
          render json: { error: GENERIC_SIGNUP_ERROR }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        # E-L5: Rails-level uniqueness を通った後、DB unique で race を弾かれた場合
        # 500 を出さず E-H1 と同じ汎用 422 で応答 (email 列挙防止も継続)
        Rails.logger.info("[signup][422] db_unique_race")
        render json: { error: GENERIC_SIGNUP_ERROR }, status: :unprocessable_entity
      end

      def login
        email = params[:email].to_s.downcase.strip
        password = params[:password].to_s
        user = User.find_by(email: email)
        authenticated =
          if user
            user.authenticate(password)
          else
            # E-H2: ダミー bcrypt を必ず実行してレイテンシを揃える (戻り値は破棄)
            BCrypt::Password.new(DUMMY_DIGEST).is_password?(password)
            false
          end

        if authenticated
          issue_jwt_cookie(user)
          render json: { user: user_payload(user) }
        else
          render json: { error: "メールアドレスまたはパスワードが間違っています" }, status: :unauthorized
        end
      end

      # POST /api/v1/guest_login (F-GUEST-01)
      # 訪問者ごとに一時ゲストを作り、通常のログインと同じ Cookie を発行する。
      # ログイン中に呼ばれた場合も、ゲストの Cookie で上書きする。
      def guest_login
        # 先に期限切れを削除してから数える (削除前に数えると、期限切れで上限に達したと誤判定する)
        User.cleanup_expired_guests!
        if User.active_guests.count >= User::GUEST_MAX_ACTIVE
          return render(json: { error: GUEST_BUSY_ERROR }, status: :service_unavailable)
        end

        guest = User.create_guest!
        follow_guest_by_demo_users(guest)
        issue_jwt_cookie(guest)
        render json: { user: user_payload(guest) }, status: :created
      end

      def logout
        # E-M2: cookie を消すだけでなく jti を denylist に登録し、流出 token を無効化
        token = cookies.encrypted[ApplicationController::COOKIE_NAME]
        if token.present? && (payload = JsonWebToken.decode(token)) && payload[:jti] && payload[:exp]
          begin
            RevokedJti.revoke!(jti: payload[:jti], expires_at: Time.at(payload[:exp]))
            # logout はそれほど頻発しない (= cleanup の機会としてちょうど良い)
            RevokedJti.cleanup_expired!
          rescue => e
            # denylist 障害でも cookie 削除 + 204 は保証する (UX: 500 で「ログアウトできない」を防ぐ)
            # 流出 token が exp までは有効になる劣化はあるが、cookie 削除という第一防衛は機能
            Rails.logger.warn("[logout] denylist failure: #{e.class}: #{e.message}")
          end
        end
        clear_jwt_cookie
        head :no_content
      end

      def me
        if current_user
          render json: { user: user_payload(current_user) }
        else
          render json: { user: nil }
        end
      end

      # PATCH /api/v1/me: 本人プロフィール更新 (display_name / bio / avatar)
      def update_me
        return render(json: { error: "ログインが必要です" }, status: :unauthorized) unless current_user
        if current_user.update(profile_params)
          render json: { user: user_payload(current_user) }
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      # テストで切り替えられるよう、起動時ではなくリクエストのたびに読む。未設定なら有効
      def signup_enabled?
        ENV.fetch("SIGNUP_ENABLED", "true") != "false"
      end

      def signup_params
        params.permit(:email, :password, :display_name)
      end

      def profile_params
        params.permit(:display_name, :bio, :avatar)
      end

      # 初回通知: デモユーザーがゲストをフォローすると、Follow の after_commit で
      # ゲスト宛ての通知ができる。デモデータの無い環境では何もしない。
      def follow_guest_by_demo_users(guest)
        User.demo_users.limit(DEMO_FOLLOWERS_FOR_GUEST).each do |demo|
          demo.active_follows.create!(followed: guest)
        end
      end

      def user_payload(user)
        {
          id: user.id,
          email: user.email,
          display_name: user.display_name,
          bio: user.bio,
          guest: user.guest,
          avatar_url: user.avatar.attached? ? Rails.application.routes.url_helpers.rails_blob_path(user.avatar, only_path: true) : nil
        }
      end
    end
  end
end
