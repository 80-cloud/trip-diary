require "test_helper"

class MemoTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @trip = trips(:bob_okinawa)
  end

  test "user / trip / body が必須" do
    memo = Memo.new
    refute memo.valid?
    assert_includes memo.errors[:user], "must exist"
    assert_includes memo.errors[:trip], "must exist"
    assert_includes memo.errors[:body], "can't be blank"
  end

  test "body は 2000 文字以内" do
    memo = Memo.new(user: @user, trip: @trip, body: "あ" * 2001)
    refute memo.valid?
    assert_includes memo.errors[:body], "is too long (maximum is 2000 characters)"
  end

  # F-MEMO-01 受け入れ条件: 同 user/trip ペアは一意 (1 memo / pair)
  test "(user_id, trip_id) は一意" do
    Memo.create!(user: @user, trip: @trip, body: "後で書く")
    dup = Memo.new(user: @user, trip: @trip, body: "他の内容")
    refute dup.valid?
  end

  test "異なる user は同じ trip にメモを残せる" do
    Memo.create!(user: @user, trip: @trip, body: "alice のメモ")
    bobs = Memo.new(user: users(:bob), trip: @trip, body: "bob のメモ")
    assert bobs.valid?
  end
end
