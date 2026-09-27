require "test_helper"

# db/seeds.rb が最後まで成功することを固定する (Issue #102)。
# seeds は development 以外では何もしない (`return unless Rails.env.development?`) うえ、
# 旅行記録が 0 件のときしか旅行を作らないため、テスト内で両方の条件を作ってから読み込む。
class SeedsTest < ActiveSupport::TestCase
  test "development で旅行記録 0 件なら 3 件すべて category つきで作られる" do
    Trip.destroy_all
    original_env = Rails.env
    Rails.env = "development"

    capture_io { load Rails.root.join("db/seeds.rb") }

    trips = Trip.where(title: [ "京都3日間の旅", "ハワイ・オアフ島ひとり旅", "北海道 雪まつり弾丸" ])
    assert_equal 3, trips.count
    trips.each { |trip| assert trip.category.present?, "#{trip.title} に category がない" }
  ensure
    Rails.env = original_env
  end
end
