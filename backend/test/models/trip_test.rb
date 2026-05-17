require "test_helper"

class TripTest < ActiveSupport::TestCase
  # F-CAT-01 受け入れ条件: カテゴリ未選択 → バリデーションエラー
  test "category は必須" do
    trip = trips(:alice_kyoto).dup
    trip.category = nil
    refute trip.valid?
    assert_includes trip.errors[:category], "can't be blank"
  end

  test "category は許容値のみ受け付ける" do
    trip = trips(:alice_kyoto)
    assert_raises(ArgumentError) { trip.category = "invalid_category" }
  end

  test "Trip.categories に 8 種類が定義されている" do
    assert_equal %w[domestic overseas solo gourmet heritage family outdoor business].sort,
                 Trip.categories.keys.sort
  end

  # F-TAG-01 受け入れ条件: tag_list= でタグを付与し has_many :tags で参照できる
  test "tag_list= で複数タグを付与できる" do
    trip = trips(:alice_kyoto)
    trip.tag_list = ["京都", "紅葉", "寺"]
    trip.save!
    assert_equal %w[京都 紅葉 寺].sort, trip.reload.tags.map(&:name).sort
  end

  test "tag_list= は既存タグを再利用する" do
    Tag.create!(name: "京都")
    trip = trips(:alice_kyoto)
    trip.tag_list = ["京都", "紅葉"]
    trip.save!
    assert_equal 2, Tag.count, "重複タグは再利用される (新規作成しない)"
  end

  test "tag_list= で空配列を渡すと既存タグが全削除される" do
    trip = trips(:alice_kyoto)
    trip.tag_list = ["京都"]
    trip.save!
    trip.tag_list = []
    trip.save!
    assert_empty trip.reload.tags
  end

  # F-TAG-02 受け入れ条件
  test ".by_tag(name) で該当 Trip のみ返す" do
    trip_a = trips(:alice_kyoto)
    trip_b = trips(:bob_okinawa)
    trip_a.tag_list = ["京都"]
    trip_a.save!
    trip_b.tag_list = ["沖縄"]
    trip_b.save!

    results = Trip.by_tag("京都")
    assert_includes results, trip_a
    refute_includes results, trip_b
  end

  # F-CAT-02 受け入れ条件
  test ".by_category(value) で該当 Trip のみ返す" do
    overseas = Trip.by_category("overseas")
    assert_includes overseas, trips(:bob_paris)
    refute_includes overseas, trips(:alice_kyoto)
  end

  # F-SEARCH-01 受け入れ条件: OR 横断検索 (title / destination / tag)
  test ".search(q) はタイトル/場所/タグの OR 横断検索を行う" do
    trips(:alice_kyoto).update!(tag_list: ["桜"])

    by_title       = Trip.search("3 日間")
    by_destination = Trip.search("沖縄")
    by_tag_name    = Trip.search("桜")

    assert_includes by_title,       trips(:alice_kyoto)
    assert_includes by_destination, trips(:bob_okinawa)
    assert_includes by_tag_name,    trips(:alice_kyoto)
  end

  test ".search(q) は LIKE 特殊文字 (%/_) をエスケープする" do
    trips(:alice_kyoto).update!(title: "京都 100% 楽しんだ")
    results_pct = Trip.search("100%")
    assert_includes results_pct, trips(:alice_kyoto)
    # 「%」がワイルドカード化されると無関係 Trip も拾うはずだが、エスケープされていれば拾わない
    refute_includes results_pct, trips(:bob_okinawa)
  end

  # F-SEARCH-03 受け入れ条件: 期間絞り込み
  test ".in_date_range(from, to) は期間内 Trip のみ返す" do
    results = Trip.in_date_range(Date.new(2026, 5, 1), Date.new(2026, 5, 31))
    assert_includes results, trips(:bob_okinawa)
    assert_includes results, trips(:bob_paris)
    refute_includes results, trips(:alice_kyoto)
  end

  # F-SEARCH-02 受け入れ条件: ソート
  test ".sorted(:popular) は likes_count 降順" do
    trips(:bob_okinawa).update_columns(likes_count: 10)
    trips(:alice_kyoto).update_columns(likes_count: 3)
    sorted = Trip.sorted(:popular).limit(2).pluck(:id)
    assert_equal trips(:bob_okinawa).id, sorted.first
  end

  test ".sorted(:title) は title 昇順" do
    sorted_ids = Trip.sorted(:title).pluck(:id)
    expected_order = Trip.all.sort_by { |t| t.title }.map(&:id)
    assert_equal expected_order, sorted_ids
  end

  test ".sorted(:recent) は created_at 降順 (デフォルト)" do
    sorted_ids = Trip.sorted(:recent).pluck(:id)
    expected_order = Trip.all.sort_by { |t| t.created_at }.reverse.map(&:id)
    assert_equal expected_order, sorted_ids
  end

  # 33 文字以上のタグを渡すと Tag.create! が後付けで 500 になる罠を、
  # Trip 側のプリバリデーションで 422 に倒すことを保証する。
  test "tag_list= で 32 文字超のタグは validation で弾く" do
    trip = trips(:alice_kyoto)
    trip.tag_list = ["あ" * 33]
    refute trip.valid?
    assert_includes trip.errors[:tags], "は各 32 文字以内にしてください"
  end
end
