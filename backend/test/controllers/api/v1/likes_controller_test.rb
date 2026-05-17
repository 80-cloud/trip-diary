require "test_helper"

class Api::V1::LikesControllerTest < ActionDispatch::IntegrationTest
  # PR #20 で発見した可視性バイパス回帰テスト:
  # likes_controller の set_trip が Trip.find を直接呼んでいたため、
  # 他人の draft/private trip に ID 直打ちでいいね可能だった (情報漏洩 + 不正書込)。

  test "他人の draft trip にいいねできない (404)" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_draft).id}/like"
    assert_response :not_found
  end

  test "他人の private trip にいいねできない (404)" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_private).id}/like"
    assert_response :not_found
  end

  test "公開 trip にはいいねできる (まだ like していないユーザーで検証)" do
    # carol は fixture で likes に登場しない。assert_difference で +1 を確認する
    # (likes.yml の counter_cache は fixture 直値ではなく差分で検証 — trips.yml の方針に従う)
    login_via_api(users(:carol))
    assert_difference -> { trips(:alice_kyoto).reload.likes_count }, 1 do
      post "/api/v1/trips/#{trips(:alice_kyoto).id}/like"
    end
    assert_response :created
    assert JSON.parse(response.body)["liked"]
  end

  test "自分の draft trip には自分でいいねできる (visible_to で本人は通る)" do
    login_via_api(users(:alice))
    post "/api/v1/trips/#{trips(:alice_draft).id}/like"
    assert_response :created
  end
end
