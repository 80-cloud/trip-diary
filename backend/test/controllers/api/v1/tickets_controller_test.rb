require "test_helper"

class Api::V1::TicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:alice)
    @trip  = trips(:alice_kyoto)
  end

  test "POST で本人がチケットを作成 (201)" do
    login_via_api(@owner)
    assert_difference -> { Ticket.count }, 1 do
      post "/api/v1/trips/#{@trip.id}/tickets",
        params: { kind: "train", reservation_no: "12345" }, as: :json
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "train", body["kind"]
  end

  test "POST: kind 不正値は other にサニタイズされる (500 回避)" do
    login_via_api(@owner)
    post "/api/v1/trips/#{@trip.id}/tickets",
      params: { kind: "invalid_xyz", reservation_no: "X" }, as: :json
    assert_response :created
    assert_equal "other", JSON.parse(response.body)["kind"]
  end

  test "POST: 4 field 全て空は 422" do
    login_via_api(@owner)
    post "/api/v1/trips/#{@trip.id}/tickets", params: { kind: "train" }, as: :json
    assert_response :unprocessable_entity
  end

  test "他人 trip (公開) → 403" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{@trip.id}/tickets",
      params: { kind: "train", reservation_no: "X" }, as: :json
    assert_response :forbidden
  end

  test "他人 trip (非公開) → 404" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_private).id}/tickets",
      params: { kind: "train", reservation_no: "X" }, as: :json
    assert_response :not_found
  end

  test "未ログインで POST → 401" do
    post "/api/v1/trips/#{@trip.id}/tickets",
      params: { kind: "train", reservation_no: "X" }, as: :json
    assert_response :unauthorized
  end

  test "PATCH で更新" do
    ticket = @trip.tickets.create!(kind: "train", reservation_no: "old")
    login_via_api(@owner)
    patch "/api/v1/trips/#{@trip.id}/tickets/#{ticket.id}",
      params: { reservation_no: "new" }, as: :json
    assert_response :ok
    assert_equal "new", ticket.reload.reservation_no
  end

  test "DELETE で削除" do
    ticket = @trip.tickets.create!(kind: "train", reservation_no: "x")
    login_via_api(@owner)
    assert_difference -> { Ticket.count }, -1 do
      delete "/api/v1/trips/#{@trip.id}/tickets/#{ticket.id}"
    end
  end

  test "trip 詳細 (本人) は tickets を返す" do
    @trip.tickets.create!(kind: "train", reservation_no: "12345")
    login_via_api(@owner)
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_equal 1, body["tickets"].size
    assert_equal "12345", body["tickets"].first["reservation_no"]
  end

  test "trip 詳細 (他人) は tickets を空配列で返す (機密情報漏洩防止)" do
    @trip.tickets.create!(kind: "train", reservation_no: "12345")
    login_via_api(users(:bob))
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_equal [], body["tickets"]
  end
end
