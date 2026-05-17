require "test_helper"

class Api::V1::ReceiptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:alice)
    @trip  = trips(:alice_kyoto)
  end

  test "POST で本人がレシート作成 (201)" do
    login_via_api(@owner)
    assert_difference -> { Receipt.count }, 1 do
      post "/api/v1/trips/#{@trip.id}/receipts",
        params: { amount: 1200, category: "food", description: "ラーメン", spent_on: "2026-04-02" }, as: :json
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "food", body["category"]
    assert_equal "1200.00", body["amount"]
  end

  test "POST: category 不正値は other にサニタイズ" do
    login_via_api(@owner)
    post "/api/v1/trips/#{@trip.id}/receipts",
      params: { amount: 500, category: "junk" }, as: :json
    assert_response :created
    assert_equal "other", JSON.parse(response.body)["category"]
  end

  test "POST: amount 0 は 422" do
    login_via_api(@owner)
    post "/api/v1/trips/#{@trip.id}/receipts",
      params: { amount: 0, category: "food" }, as: :json
    assert_response :unprocessable_entity
  end

  test "他人 trip (公開) → 403" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{@trip.id}/receipts",
      params: { amount: 100, category: "food" }, as: :json
    assert_response :forbidden
  end

  test "他人 trip (非公開) → 404" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_private).id}/receipts",
      params: { amount: 100, category: "food" }, as: :json
    assert_response :not_found
  end

  test "未ログインで POST → 401" do
    post "/api/v1/trips/#{@trip.id}/receipts",
      params: { amount: 100, category: "food" }, as: :json
    assert_response :unauthorized
  end

  test "PATCH で更新" do
    receipt = @trip.receipts.create!(amount: 100, category: "food")
    login_via_api(@owner)
    patch "/api/v1/trips/#{@trip.id}/receipts/#{receipt.id}",
      params: { amount: 200 }, as: :json
    assert_response :ok
    assert_equal 200, receipt.reload.amount.to_i
  end

  test "DELETE で削除" do
    receipt = @trip.receipts.create!(amount: 100, category: "food")
    login_via_api(@owner)
    assert_difference -> { Receipt.count }, -1 do
      delete "/api/v1/trips/#{@trip.id}/receipts/#{receipt.id}"
    end
    assert_response :no_content
  end

  test "trip 詳細 (本人) は budget / receipts / 集計を返す" do
    Budget.create!(trip: @trip, planned_amount: 30000)
    @trip.receipts.create!(amount: 1000, category: "food")
    @trip.receipts.create!(amount: 5000, category: "lodging")
    @trip.receipts.create!(amount: 2000, category: "food")
    login_via_api(@owner)
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_equal "30000.00", body["budget"]["planned_amount"]
    assert_equal 3, body["receipts"].size
    assert_equal "8000.00", body["receipts_total"]
    assert_equal "3000.00", body["receipts_by_category"]["food"]
    assert_equal "5000.00", body["receipts_by_category"]["lodging"]
    assert_equal "0.00",    body["receipts_by_category"]["transport"]
  end

  test "trip 詳細 (他人) は budget / receipts を出さない (機密漏洩防止)" do
    Budget.create!(trip: @trip, planned_amount: 30000)
    @trip.receipts.create!(amount: 1000, category: "food")
    login_via_api(users(:bob))
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_nil body["budget"]
    assert_equal [], body["receipts"]
    assert_nil body["receipts_total"]
    assert_nil body["receipts_by_category"]
  end
end
