require "test_helper"

# 公開環境の DB (TiDB) は FOR UPDATE SKIP LOCKED に対応していない (Issue #156)。
# 本番の設定はテストの環境では読まれないため、ファイルを読み直して確かめる。
class SolidQueueLockTest < ActiveSupport::TestCase
  test "本番は Solid Queue に SKIP LOCKED を使わせない" do
    lines = Rails.root.join("config/environments/production.rb").readlines.map(&:strip)

    settings = lines.select { |line| line.start_with?("config.solid_queue.use_skip_locked") }

    assert_equal [ "config.solid_queue.use_skip_locked = false" ], settings
  end

  test "使っている Solid Queue に use_skip_locked の設定がある" do
    assert_respond_to SolidQueue, :use_skip_locked=
  end
end
