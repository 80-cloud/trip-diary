# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # trip-diary 追加 (docs/ログ・監視・障害対応設計書.md §2-3 と連動):
  # - :jwt        JWT トークン文字列を含むキー名 (jwt_token, jwt_secret 等)
  # - :authorization  Authorization という名前のパラメータがある場合 (※ HTTP ヘッダ
  #                   はこの仕組みでは隠れない。Rails デフォルトでヘッダはログに出ない
  #                   ため通常問題ないが、意図的に request.headers を出す場合は別途
  #                   middleware で対応する必要あり — Phase 2 課題)
  # - :api_key    :_key (部分マッチ) でも捕捉できるが、意図明示のため冗長定義
  :jwt, :authorization, :api_key
]
