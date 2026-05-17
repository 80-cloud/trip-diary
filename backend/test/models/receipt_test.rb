require "test_helper"

class ReceiptTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:alice_kyoto)
  end

  test "amount は 0 より大" do
    refute Receipt.new(trip: @trip, amount: 0, category: "food").valid?
    refute Receipt.new(trip: @trip, amount: -10, category: "food").valid?
    assert Receipt.new(trip: @trip, amount: 1, category: "food").valid?
    assert Receipt.new(trip: @trip, amount: 9999.99, category: "food").valid?
  end

  test "category は許可リストのみ" do
    Receipt::CATEGORIES.each do |c|
      assert Receipt.new(trip: @trip, amount: 1, category: c).valid?, "category=#{c} は valid"
    end
    refute Receipt.new(trip: @trip, amount: 1, category: "junk").valid?
  end

  test "description は 200 文字以内" do
    assert Receipt.new(trip: @trip, amount: 1, category: "food", description: "a" * 200).valid?
    refute Receipt.new(trip: @trip, amount: 1, category: "food", description: "a" * 201).valid?
  end

  test "ordered scope は spent_on 降順" do
    Receipt.create!(trip: @trip, amount: 100, category: "food", spent_on: Date.new(2026, 4, 1))
    Receipt.create!(trip: @trip, amount: 200, category: "food", spent_on: Date.new(2026, 4, 3))
    Receipt.create!(trip: @trip, amount: 300, category: "food", spent_on: Date.new(2026, 4, 2))
    amounts = @trip.receipts.ordered.pluck(:amount).map(&:to_i)
    assert_equal [200, 300, 100], amounts
  end
end
