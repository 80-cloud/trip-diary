require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_trip = trips(:alice_kyoto) # owner = alice
  end

  # ----- バリデーション -----

  test "body 必須・140 文字以内" do
    refute Comment.new(trip: @alice_trip, user: @bob).valid?
    refute Comment.new(trip: @alice_trip, user: @bob, body: "a" * 141).valid?
    assert Comment.new(trip: @alice_trip, user: @bob, body: "a" * 140).valid?
  end

  # ----- F-NOTIF-01 hook -----

  test "他人の trip にコメントすると trip 所有者へ通知が作成される" do
    assert_difference -> { Notification.count }, 1 do
      Comment.create!(trip: @alice_trip, user: @bob, body: "コメント")
    end
    n = Notification.last
    assert_equal @alice.id, n.recipient_id
    assert_equal @bob.id,   n.actor_id
    assert_equal "commented", n.verb
    assert_equal "Comment", n.target_type
  end

  test "自分の trip にコメントしても通知は作成されない (自己アクション除外)" do
    assert_no_difference -> { Notification.count } do
      Comment.create!(trip: @alice_trip, user: @alice, body: "セルフコメント")
    end
  end
end
