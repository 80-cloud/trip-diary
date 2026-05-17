require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @trip = trips(:bob_okinawa)
  end

  test "user と trip が必須" do
    fav = Favorite.new
    refute fav.valid?
    assert_includes fav.errors[:user], "must exist"
    assert_includes fav.errors[:trip], "must exist"
  end

  # F-FAV-01 受け入れ条件: 同 user/trip ペアは一意
  test "(user_id, trip_id) は一意 (validation レイヤ)" do
    Favorite.create!(user: @user, trip: @trip)
    dup = Favorite.new(user: @user, trip: @trip)
    refute dup.valid?
  end

  test "(user_id, trip_id) は DB レイヤでも unique (race の最終防衛)" do
    Favorite.create!(user: @user, trip: @trip)
    assert_raises(ActiveRecord::RecordNotUnique) do
      # validation を bypass して DB に直書き → unique index で弾かれる
      Favorite.new(user: @user, trip: @trip).save(validate: false)
    end
  end
end
