class ApplicationController < ActionController::API
  include ActionController::Cookies

  COOKIE_NAME = :trip_diary_token

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable

  private

  def current_user
    return @current_user if defined?(@current_user)
    token = cookies.encrypted[COOKIE_NAME] || token_from_header
    @current_user = nil
    return @current_user if token.blank?

    payload = JsonWebToken.decode(token)
    @current_user = User.find_by(id: payload[:user_id]) if payload
  end

  def authenticate_user!
    return if current_user
    render json: { error: "ログインが必要です" }, status: :unauthorized
  end

  def issue_jwt_cookie(user)
    token = JsonWebToken.encode({ user_id: user.id })
    cookies.encrypted[COOKIE_NAME] = {
      value: token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax,
      expires: 1.day.from_now
    }
  end

  def clear_jwt_cookie
    cookies.delete(COOKIE_NAME)
  end

  def token_from_header
    auth = request.headers["Authorization"]
    return nil unless auth&.start_with?("Bearer ")
    auth.split(" ", 2).last
  end

  def render_not_found
    render json: { error: "リソースが見つかりません" }, status: :not_found
  end

  def render_unprocessable(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end
end
