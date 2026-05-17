require "test_helper"

class BudgetTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:alice_kyoto)
  end

  test "planned_amount は 0 以上" do
    refute Budget.new(trip: @trip, planned_amount: -1).valid?
    assert Budget.new(trip: @trip, planned_amount: 0).valid?
    assert Budget.new(trip: @trip, planned_amount: 100000).valid?
  end

  test "currency は許可リストのみ" do
    assert Budget.new(trip: @trip, planned_amount: 0, currency: "JPY").valid?
    refute Budget.new(trip: @trip, planned_amount: 0, currency: "XYZ").valid?
    refute Budget.new(trip: @trip, planned_amount: 0, currency: "").valid?
  end

  test "1 trip 1 budget (uniqueness)" do
    Budget.create!(trip: @trip, planned_amount: 1000)
    dup = Budget.new(trip: @trip, planned_amount: 2000)
    refute dup.valid?
  end

  test "DB unique index でも race を弾く" do
    Budget.create!(trip: @trip, planned_amount: 1000)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Budget.new(trip: @trip, planned_amount: 2000).save(validate: false)
    end
  end
end
