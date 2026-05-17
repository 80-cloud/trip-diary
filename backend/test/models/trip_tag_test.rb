require "test_helper"

class TripTagTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:alice_kyoto)
    @tag  = Tag.create!(name: "紅葉")
  end

  test "trip と tag が必須" do
    tt = TripTag.new
    refute tt.valid?
    assert_includes tt.errors[:trip], "must exist"
    assert_includes tt.errors[:tag],  "must exist"
  end

  test "(trip_id, tag_id) は一意" do
    TripTag.create!(trip: @trip, tag: @tag)
    dup = TripTag.new(trip: @trip, tag: @tag)
    refute dup.valid?
  end
end
