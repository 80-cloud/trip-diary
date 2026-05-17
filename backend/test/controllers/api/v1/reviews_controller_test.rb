require "test_helper"

class Api::V1::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:alice)
    @trip  = trips(:alice_kyoto)
  end

  test "PUT で初回レビュー作成 (200)" do
    login_via_api(@owner)
    assert_difference -> { Review.count }, 1 do
      put "/api/v1/trips/#{@trip.id}/review",
        params: { rating: 5, body: "最高" }, as: :json
    end
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 5, body["rating"]
    assert_equal "最高", body["body"]
  end

  test "PUT で既存レビュー更新 (upsert)" do
    Review.create!(trip: @trip, rating: 3, body: "まあまあ")
    login_via_api(@owner)
    assert_no_difference -> { Review.count } do
      put "/api/v1/trips/#{@trip.id}/review",
        params: { rating: 5, body: "やっぱり最高" }, as: :json
    end
    assert_response :ok
    review = @trip.reload.review
    assert_equal 5, review.rating
    assert_equal "やっぱり最高", review.body
  end

  test "PUT: rating 範囲外は 422" do
    login_via_api(@owner)
    [ 0, 6, -1 ].each do |r|
      put "/api/v1/trips/#{@trip.id}/review", params: { rating: r }, as: :json
      assert_response :unprocessable_entity
    end
  end

  test "PUT: body 2001 文字は 422" do
    login_via_api(@owner)
    put "/api/v1/trips/#{@trip.id}/review",
      params: { rating: 5, body: "あ" * 2001 }, as: :json
    assert_response :unprocessable_entity
  end

  test "DELETE でレビュー削除" do
    Review.create!(trip: @trip, rating: 5)
    login_via_api(@owner)
    assert_difference -> { Review.count }, -1 do
      delete "/api/v1/trips/#{@trip.id}/review"
    end
  end

  test "DELETE が無くても 204 (冪等)" do
    login_via_api(@owner)
    delete "/api/v1/trips/#{@trip.id}/review"
    assert_response :no_content
  end

  test "他人 trip (公開) への PUT は 403" do
    login_via_api(users(:bob))
    put "/api/v1/trips/#{@trip.id}/review", params: { rating: 5 }, as: :json
    assert_response :forbidden
  end

  test "他人 trip (非公開) への PUT は 404" do
    login_via_api(users(:bob))
    put "/api/v1/trips/#{trips(:alice_private).id}/review", params: { rating: 5 }, as: :json
    assert_response :not_found
  end

  test "trip 詳細レスポンスに review (公開情報)" do
    Review.create!(trip: @trip, rating: 4, body: "良かった")
    get "/api/v1/trips/#{@trip.id}" # 未ログインでも見える
    body = JSON.parse(response.body)
    assert_equal 4, body["review"]["rating"]
    assert_equal "良かった", body["review"]["body"]
  end

  test "trip 詳細 review なしなら null" do
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_nil body["review"]
  end
end
