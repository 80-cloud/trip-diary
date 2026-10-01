require "test_helper"

class PlannedSpotTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:alice_kyoto)
  end

  test "title が必須" do
    spot = PlannedSpot.new(trip: @trip)
    refute spot.valid?
    assert_includes spot.errors[:title], "can't be blank"
  end

  test "title は 80 文字以内" do
    spot = PlannedSpot.new(trip: @trip, title: "あ" * 81)
    refute spot.valid?
    assert_includes spot.errors[:title], "is too long (maximum is 80 characters)"
  end

  test "デフォルト done=false / day_entry_id=nil" do
    spot = PlannedSpot.create!(trip: @trip, title: "金閣寺")
    refute spot.done
    assert_nil spot.day_entry_id
  end

  # F-PLAN-02 受け入れ条件: done を false→true で DayEntry 自動作成
  test "done を false → true に更新すると DayEntry が作成され紐付く" do
    spot = PlannedSpot.create!(trip: @trip, title: "銀閣寺")
    assert_difference -> { @trip.day_entries.count }, 1 do
      spot.update!(done: true)
    end
    assert spot.reload.day_entry_id.present?
    assert_equal "銀閣寺", spot.day_entry.title
  end

  # F-PLAN-02 受け入れ条件: 冪等性 (再度 done=true でも追加作成しない)
  test "done=true の再更新では DayEntry を重複作成しない" do
    spot = PlannedSpot.create!(trip: @trip, title: "二条城")
    spot.update!(done: true)
    assert_no_difference -> { @trip.day_entries.count } do
      spot.update!(done: true)  # 何も変わらないが触る
      spot.update!(title: "二条城 改題")  # done は変わらないので発火しない
    end
  end

  # F-PLAN-02 受け入れ条件: true→false で DayEntry は削除しない
  test "done を true → false に戻しても DayEntry は残る" do
    spot = PlannedSpot.create!(trip: @trip, title: "清水寺")
    spot.update!(done: true)
    day_id = spot.day_entry_id
    assert_no_difference -> { @trip.day_entries.count } do
      spot.update!(done: false)
    end
    # day_entry_id は残す (誤操作復元のため)
    assert_equal day_id, spot.reload.day_entry_id
  end

  test ".ordered は position 昇順" do
    a = PlannedSpot.create!(trip: @trip, title: "A", position: 2)
    b = PlannedSpot.create!(trip: @trip, title: "B", position: 1)
    assert_equal [ b, a ], @trip.planned_spots.ordered.to_a
  end

  # Issue #160: 日記に昇格したスポットがあっても、旅行と日記を消せる
  test "昇格したスポットがある旅行を消すと、日記とスポットも消える" do
    spot = PlannedSpot.create!(trip: @trip, title: "嵐山")
    spot.update!(done: true)
    day_id = spot.reload.day_entry_id
    @trip.destroy!
    assert_not PlannedSpot.exists?(spot.id)
    assert_not DayEntry.exists?(day_id)
  end

  test "昇格元の日記だけを消すと、スポットは残り day_entry_id が nil になる" do
    spot = PlannedSpot.create!(trip: @trip, title: "伏見稲荷")
    spot.update!(done: true)
    spot.reload.day_entry.destroy!
    assert_nil spot.reload.day_entry_id
  end

  test "DB の外部キーでも、日記が消えるとスポットの day_entry_id が nil になる" do
    spot = PlannedSpot.create!(trip: @trip, title: "南禅寺")
    spot.update!(done: true)
    DayEntry.where(id: spot.reload.day_entry_id).delete_all
    assert_nil spot.reload.day_entry_id
  end
end
