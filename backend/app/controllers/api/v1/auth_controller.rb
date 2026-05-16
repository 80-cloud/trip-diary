module Api
  module V1
    class AuthController < BaseController
      def signup
        user = User.new(signup_params)
        if user.save
          issue_jwt_cookie(user)
          render json: { user: user_payload(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: params[:email].to_s.downcase.strip)
        if user&.authenticate(params[:password])
          issue_jwt_cookie(user)
          render json: { user: user_payload(user) }
        else
          render json: { error: "メールアドレスまたはパスワードが間違っています" }, status: :unauthorized
        end
      end

      def logout
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
