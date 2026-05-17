require "test_helper"

class Api::V1::PackingItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:alice)
    @trip  = trips(:alice_kyoto)
  end

  test "POST で本人が packing_item を作成 (201)" do
    login_via_api(@owner)
    assert_difference -> { PackingItem.count }, 1 do
      post "/api/v1/trips/#{@trip.id}/packing_items",
        params: { body: "歯ブラシ" }, as: :json
    end
    assert_response :created
  end

  test "PATCH packed=true で更新" do
    item = @trip.packing_items.create!(body: "歯ブラシ")
    login_via_api(@owner)
    patch "/api/v1/trips/#{@trip.id}/packing_items/#{item.id}",
      params: { packed: true }, as: :json
    assert_response :ok
    assert JSON.parse(response.body)["packed"]
  end

  test "DELETE で削除" do
    item = @trip.packing_items.create!(body: "歯ブラシ")
    login_via_api(@owner)
    assert_difference -> { PackingItem.count }, -1 do
      delete "/api/v1/trips/#{@trip.id}/packing_items/#{item.id}"
    end
  end

  test "他人 trip への POST は 403 (見える)" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{@trip.id}/packing_items",
      params: { body: "侵入" }, as: :json
    assert_response :forbidden
  end

  test "他人 (見えない trip) への POST は 404" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_private).id}/packing_items",
      params: { body: "x" }, as: :json
    assert_response :not_found
  end

  test "trip 詳細 (本人) は packing_items の中身を返す" do
    item = @trip.packing_items.create!(body: "歯ブラシ")
    login_via_api(@owner)
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_equal 1, body["packing_items"].size
    assert_equal item.id, body["packing_items"].first["id"]
  end

  test "trip 詳細 (他人) は packing_items を空配列で返す (情報漏洩防止)" do
    @trip.packing_items.create!(body: "下着")
    login_via_api(users(:bob))
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_equal [], body["packing_items"]
  end
end
