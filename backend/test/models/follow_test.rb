require "test_helper"

class FollowTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
  end

  test "follower / followed が必須" do
    f = Follow.new
    refute f.valid?
    assert_includes f.errors[:follower], "must exist"
    assert_includes f.errors[:followed], "must exist"
  end

  # F-FOLLOW-01 受け入れ条件: 自分自身フォロー不可
  test "自分自身をフォローできない" do
    f = Follow.new(follower: @alice, followed: @alice)
    refute f.valid?
    assert_includes f.errors[:base], "自分自身をフォローできません"
  end

  test "(follower, followed) は一意 (validation)" do
    Follow.create!(follower: @alice, followed: @bob)
    dup = Follow.new(follower: @alice, followed: @bob)
    refute dup.valid?
  end

  test "(follower, followed) は DB unique でも弾く" do
    Follow.create!(follower: @alice, followed: @bob)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Follow.new(follower: @alice, followed: @bob).save(validate: false)
    end
  end

  # User#following? / mutual_follow?
  test "User#following? は片方向フォローを返す" do
    refute @alice.following?(@bob)
    Follow.create!(follower: @alice, followed: @bob)
    assert @alice.reload.following?(@bob)
    refute @bob.reload.following?(@alice)
  end

  test "User#mutual_follow? は相互フォローのみ true" do
    Follow.create!(follower: @alice, followed: @bob)
    refute @alice.reload.mutual_follow?(@bob), "片方向では false"
    Follow.create!(follower: @bob, followed: @alice)
    assert @alice.reload.mutual_follow?(@bob), "相互で true"
  end

  test "User#followings / followers の through 関連" do
    Follow.create!(follower: @alice, followed: @bob)
    Follow.create!(follower: @alice, followed: users(:carol))
    assert_equal [@bob, users(:carol)].sort_by(&:id), @alice.followings.order(:id).to_a
    assert_equal [@alice], @bob.followers.to_a
  end
end
