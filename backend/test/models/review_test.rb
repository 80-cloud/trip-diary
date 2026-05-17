require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:alice_kyoto)
  end

  test "rating は 1〜5 のみ" do
    [ 0, 6, -1, nil ].each do |r|
      refute Review.new(trip: @trip, rating: r).valid?, "rating=#{r.inspect} は invalid"
    end
    [ 1, 2, 3, 4, 5 ].each do |r|
      assert Review.new(trip: @trip, rating: r).valid?, "rating=#{r} は valid"
    end
  end

  test "body は 2000 文字以内 (空 OK)" do
    assert Review.new(trip: @trip, rating: 5, body: "").valid?
    assert Review.new(trip: @trip, rating: 5, body: "あ" * 2000).valid?
    refute Review.new(trip: @trip, rating: 5, body: "あ" * 2001).valid?
  end

  test "1 trip 1 review (uniqueness)" do
    Review.create!(trip: @trip, rating: 5)
    dup = Review.new(trip: @trip, rating: 4)
    refute dup.valid?
  end

  test "DB unique index でも race を弾く" do
    Review.create!(trip: @trip, rating: 5)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Review.new(trip: @trip, rating: 3).save(validate: false)
    end
  end
end
