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

      def signup
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

      def logout
        # E-M2: cookie を消すだけでなく jti を denylist に登録し、流出 token を無効化
        token = cookies.encrypted[ApplicationController::COOKIE_NAME]
        if token.present? && (payload = JsonWebToken.decode(token)) && payload[:jti] && payload[:exp]
          RevokedJti.revoke!(jti: payload[:jti], expires_at: Time.at(payload[:exp]))
          # logout はそれほど頻発しない (= cleanup の機会としてちょうど良い)
          RevokedJti.cleanup_expired!
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

      private

      def signup_params
        params.permit(:email, :password, :display_name)
      end

      def user_payload(user)
        { id: user.id, email: user.email, display_name: user.display_name, bio: user.bio }
      end
    end
  end
end
