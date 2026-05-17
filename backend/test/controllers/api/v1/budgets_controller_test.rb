require "test_helper"

class Api::V1::BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:alice)
    @trip  = trips(:alice_kyoto)
  end

  test "PUT 初回作成 (200)" do
    login_via_api(@owner)
    assert_difference -> { Budget.count }, 1 do
      put "/api/v1/trips/#{@trip.id}/budget",
        params: { planned_amount: 50000, currency: "JPY" }, as: :json
    end
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "50000.00", body["planned_amount"]
    assert_equal "JPY",     body["currency"]
  end

  test "PUT 既存更新 (upsert)" do
    Budget.create!(trip: @trip, planned_amount: 1000)
    login_via_api(@owner)
    assert_no_difference -> { Budget.count } do
      put "/api/v1/trips/#{@trip.id}/budget",
        params: { planned_amount: 9999 }, as: :json
    end
    assert_response :ok
    assert_equal "9999.00", JSON.parse(response.body)["planned_amount"]
  end

  test "PUT: currency 不正値は JPY にサニタイズ (500 回避)" do
    login_via_api(@owner)
    put "/api/v1/trips/#{@trip.id}/budget",
      params: { planned_amount: 100, currency: "XYZ" }, as: :json
    assert_response :ok
    assert_equal "JPY", JSON.parse(response.body)["currency"]
  end

  test "PUT: 負の planned_amount は 422" do
    login_via_api(@owner)
    put "/api/v1/trips/#{@trip.id}/budget",
      params: { planned_amount: -1 }, as: :json
    assert_response :unprocessable_entity
  end

  test "DELETE で予算削除" do
    Budget.create!(trip: @trip, planned_amount: 1000)
    login_via_api(@owner)
    assert_difference -> { Budget.count }, -1 do
      delete "/api/v1/trips/#{@trip.id}/budget"
    end
    assert_response :no_content
  end

  test "DELETE: 存在しない予算でも 204 (冪等)" do
    login_via_api(@owner)
    delete "/api/v1/trips/#{@trip.id}/budget"
    assert_response :no_content
  end

  test "他人 trip (公開) → 403" do
    login_via_api(users(:bob))
    put "/api/v1/trips/#{@trip.id}/budget",
      params: { planned_amount: 100 }, as: :json
    assert_response :forbidden
  end

  test "他人 trip (非公開) → 404 (存在漏洩防止)" do
    login_via_api(users(:bob))
    put "/api/v1/trips/#{trips(:alice_private).id}/budget",
      params: { planned_amount: 100 }, as: :json
    assert_response :not_found
  end

  test "未ログインで PUT → 401" do
    put "/api/v1/trips/#{@trip.id}/budget",
      params: { planned_amount: 100 }, as: :json
    assert_response :unauthorized
  end
end
