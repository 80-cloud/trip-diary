require "test_helper"

class PackingItemTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:alice_kyoto)
  end

  test "body が必須" do
    item = PackingItem.new(trip: @trip)
    refute item.valid?
    assert_includes item.errors[:body], "can't be blank"
  end

  test "body は 80 文字以内" do
    item = PackingItem.new(trip: @trip, body: "あ" * 81)
    refute item.valid?
  end

  test "デフォルト packed=false" do
    item = PackingItem.create!(trip: @trip, body: "歯ブラシ")
    refute item.packed
  end
end
