require "test_helper"

class Api::V1::PlannedSpotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:alice)
    @trip  = trips(:alice_kyoto)
  end

  # F-PLAN-01: 作成
  test "POST で本人が planned_spot を作成 (201)" do
    login_via_api(@owner)
    assert_difference -> { PlannedSpot.count }, 1 do
      post "/api/v1/trips/#{@trip.id}/planned_spots",
        params: { title: "金閣寺" }, as: :json
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "金閣寺", body["title"]
    assert_equal false, body["done"]
  end

  test "POST: 他人 trip は 404 (visible_to)" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_private).id}/planned_spots",
      params: { title: "侵入" }, as: :json
    assert_response :not_found
  end

  test "POST: 他人 (見えるが本人でない) は 403" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{@trip.id}/planned_spots",  # alice_kyoto は public
      params: { title: "侵入" }, as: :json
    assert_response :forbidden
  end

  test "POST: 未ログイン → 401" do
    post "/api/v1/trips/#{@trip.id}/planned_spots",
      params: { title: "x" }, as: :json
    assert_response :unauthorized
  end

  test "POST: title 空 → 422" do
    login_via_api(@owner)
    post "/api/v1/trips/#{@trip.id}/planned_spots", params: {}, as: :json
    assert_response :unprocessable_entity
  end

  # F-PLAN-02: done=true 昇格
  test "PATCH done=true で DayEntry が自動作成される" do
    login_via_api(@owner)
    spot = @trip.planned_spots.create!(title: "金閣寺")
    assert_difference -> { @trip.day_entries.count }, 1 do
      patch "/api/v1/trips/#{@trip.id}/planned_spots/#{spot.id}",
        params: { done: true }, as: :json
    end
    assert_response :ok
    body = JSON.parse(response.body)
    assert body["done"]
    assert body["day_entry_id"].present?
  end

  test "DELETE で planned_spot を削除" do
    login_via_api(@owner)
    spot = @trip.planned_spots.create!(title: "x")
    assert_difference -> { PlannedSpot.count }, -1 do
      delete "/api/v1/trips/#{@trip.id}/planned_spots/#{spot.id}"
    end
    assert_response :no_content
  end

  # F-PLAN-03: 進捗バー
  test "trip 詳細 (本人) は planned_count / planned_done_count を返す" do
    login_via_api(@owner)
    @trip.planned_spots.create!(title: "a")
    @trip.planned_spots.create!(title: "b", done: true)
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_equal 2, body["planned_count"]
    assert_equal 1, body["planned_done_count"]
  end

  # F-LEAK-01 fix (Issue #45): 旧仕様では他人にも count が返っていたが、
  # 配列が空でも件数が漏れれば情報漏洩のため is_owner ガード対象に変更。
  test "trip 詳細 (他人) は planned_count / planned_done_count を返さない (F-LEAK-01)" do
    @trip.planned_spots.create!(title: "a")
    @trip.planned_spots.create!(title: "b", done: true)
    login_via_api(users(:bob))
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_nil body["planned_count"]
    assert_nil body["planned_done_count"]
  end

  test "trip 詳細 (他人) は planned_spots の中身を返さない" do
    @trip.planned_spots.create!(title: "秘密プラン")
    login_via_api(users(:bob))
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_equal [], body["planned_spots"], "他人には中身を見せない"
  end

  test "trip 詳細 (本人) は planned_spots の中身を返す" do
    spot = @trip.planned_spots.create!(title: "金閣寺")
    login_via_api(@owner)
    get "/api/v1/trips/#{@trip.id}"
    body = JSON.parse(response.body)
    assert_equal 1, body["planned_spots"].size
    assert_equal spot.id, body["planned_spots"].first["id"]
  end
end
