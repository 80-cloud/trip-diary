require "test_helper"

class TicketTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:alice_kyoto)
  end

  test "kind は許容値のみ受け付ける" do
    %w[train hotel flight ticket other].each do |k|
      t = Ticket.new(trip: @trip, kind: k, reservation_no: "X")
      assert t.valid?, "kind=#{k} は valid であるべき"
    end
    invalid = Ticket.new(trip: @trip, kind: "invalid_xyz", reservation_no: "X")
    refute invalid.valid?
    assert_includes invalid.errors[:kind], "is not included in the list"
  end

  test "少なくとも 1 つの field (no/url/notes/file) が必要" do
    t = Ticket.new(trip: @trip, kind: "train")
    refute t.valid?
    assert_includes t.errors[:base], "予約番号 / URL / メモ / ファイルの少なくとも 1 つを入力してください"
  end

  test "reservation_no のみあれば valid" do
    t = Ticket.new(trip: @trip, kind: "train", reservation_no: "12345")
    assert t.valid?
  end

  test "url のみあれば valid" do
    t = Ticket.new(trip: @trip, kind: "hotel", url: "https://example.com")
    assert t.valid?
  end

  test "reservation_no は 80 文字以内" do
    t = Ticket.new(trip: @trip, kind: "train", reservation_no: "a" * 81)
    refute t.valid?
  end

  test "url は 500 文字以内" do
    t = Ticket.new(trip: @trip, kind: "train", url: "https://e.com/" + "a" * 500)
    refute t.valid?
  end
end
