require "test_helper"

# P0-9: 公開環境のサインアップ停止 (Issue #113)
# SIGNUP_ENABLED=false のとき signup は 403 を返す。ゲストログインは影響を受けない。
class Api::V1::SignupSwitchTest < ActionDispatch::IntegrationTest
  SIGNUP_PARAMS = { email: "new-user@example.com", password: "password123", display_name: "new" }.freeze

  setup do
    @original = ENV["SIGNUP_ENABLED"]
  end

  teardown do
    ENV["SIGNUP_ENABLED"] = @original
  end

  test "SIGNUP_ENABLED=false なら signup は 403 で、ユーザーも Cookie も増えない" do
    ENV["SIGNUP_ENABLED"] = "false"

    assert_no_difference -> { User.count } do
      post "/api/v1/signup", params: SIGNUP_PARAMS
    end
    assert_response :forbidden
    assert_equal Api::V1::AuthController::SIGNUP_DISABLED_ERROR, JSON.parse(response.body)["error"]
    assert cookies[ApplicationController::COOKIE_NAME.to_s].blank?
  end

  test "SIGNUP_ENABLED が未設定なら、従来どおり signup は 201" do
    ENV["SIGNUP_ENABLED"] = nil

    assert_difference -> { User.count }, 1 do
      post "/api/v1/signup", params: SIGNUP_PARAMS
    end
    assert_response :created
  end

  test "SIGNUP_ENABLED=false でもゲストログインは 201" do
    ENV["SIGNUP_ENABLED"] = "false"

    post "/api/v1/guest_login"
    assert_response :created
  end
end
