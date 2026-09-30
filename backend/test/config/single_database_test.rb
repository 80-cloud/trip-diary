require "test_helper"

# 公開環境の DB は 1 つにまとめる (Issue #146)。
# キャッシュ (回数制限に使う) とジョブ (画像の削除に使う) のテーブルは、アプリ本体の DB に置く。
class SingleDatabaseTest < ActiveSupport::TestCase
  class NoopJob < ActiveJob::Base
    def perform; end
  end

  test "本番の database.yml は DB を 1 つだけ定義する" do
    config = load_config("database.yml")["production"]

    %w[primary cache queue cable].each { |name| assert_not config.key?(name), name }
    assert_equal "mysql2", config["adapter"]
  end

  test "本番のキャッシュは、別の DB を指定しない (アプリ本体の DB を使う)" do
    assert_not load_config("cache.yml")["production"].key?("database")
  end

  test "本番の ActionCable は DB を使わない (チャンネルが無いため)" do
    assert_equal "async", load_config("cable.yml")["production"]["adapter"]
  end

  test "本番のジョブは、別の DB に接続しない" do
    assert_not_includes Rails.root.join("config/environments/production.rb").read, "connects_to"
  end

  test "キャッシュとジョブのテーブルが、アプリ本体の DB にある" do
    %w[solid_cache_entries solid_queue_jobs solid_queue_ready_executions solid_queue_processes].each do |table|
      assert ActiveRecord::Base.connection.table_exists?(table), table
    end
  end

  test "アプリ本体の DB で、キャッシュの読み書きと回数の加算ができる" do
    store = ActiveSupport::Cache.lookup_store(:solid_cache_store, namespace: "single-db-test")

    store.write("key", "value")
    assert_equal "value", store.read("key")
    assert_equal 1, store.increment("count")
    assert_equal 2, store.increment("count")
  end

  test "アプリ本体の DB に、ジョブを登録できる" do
    adapter = ActiveJob::QueueAdapters::SolidQueueAdapter.new

    assert_difference -> { SolidQueue::Job.count }, 1 do
      adapter.enqueue(NoopJob.new)
    end
  end

  private

  # 起動時に読んだ設定ではなく、ファイルを評価し直す (本番の設定はテストの環境では読まれないため)
  def load_config(name)
    YAML.safe_load(ERB.new(Rails.root.join("config", name).read).result, aliases: true)
  end
end
