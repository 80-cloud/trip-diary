require "test_helper"

class LikeTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_trip = trips(:alice_kyoto) # owner = alice
    # alice_kyoto には bob_likes_kyoto fixture (bob → alice_kyoto) が既にあり、
    # (user, trip) ペアの uniqueness 検証と衝突するため、別途 alice 所有の clean な trip を用意。
    @clean_trip = Trip.create!(
      user: @alice, title: "テスト用", destination: "東京",
      started_on: Date.new(2026, 7, 1), ended_on: Date.new(2026, 7, 2),
      visibility: "public", category: "domestic", status: "published"
    )
  end

  test "(user, trip) ペアは一意" do
    Like.create!(user: @bob, trip: @clean_trip)
    refute Like.new(user: @bob, trip: @clean_trip).valid?
  end

  # ----- F-NOTIF-01 hook -----

  test "他人の trip にいいねすると trip 所有者へ通知が作成される" do
    assert_difference -> { Notification.count }, 1 do
      Like.create!(user: @bob, trip: @clean_trip)
    end
    n = Notification.last
    assert_equal @alice.id, n.recipient_id
    assert_equal @bob.id,   n.actor_id
    assert_equal "liked", n.verb
    assert_equal "Like", n.target_type
  end

  test "自分の trip にいいねしても通知は作成されない (自己アクション除外)" do
    assert_no_difference -> { Notification.count } do
      Like.create!(user: @alice, trip: @clean_trip)
    end
  end
end
