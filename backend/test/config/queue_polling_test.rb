require "test_helper"

# 公開環境 (Render Free) では、ジョブの見回りが外への通信の大半を占め、月の帯域 (5 GB) を超える見込みだった (Issue #165)。
# 手元の測定では、Worker 0.1 秒・Dispatcher 1 秒は 1 時間に約 26 MB、Worker 2 秒・Dispatcher 5 秒は約 2 MB だった。
# 本番だけ間隔を広げ、開発とテストは今までどおりにする。
class QueuePollingTest < ActiveSupport::TestCase
  test "本番の Worker は 2 秒ごと、Dispatcher は 5 秒ごとに見回る" do
    config = queue_config("production")

    assert_equal 2, config["workers"].sole["polling_interval"]
    assert_equal 5, config["dispatchers"].sole["polling_interval"]
  end

  test "本番で見回りの間隔を上書きしても、ほかの設定は今までどおり" do
    config = queue_config("production")
    worker = config["workers"].sole

    assert_equal "*", worker["queues"]
    assert_equal 3, worker["threads"]
    assert_equal 1, worker["processes"]
    assert_equal 500, config["dispatchers"].sole["batch_size"]
  end

  test "開発とテストの見回りの間隔は今までどおり" do
    %w[development test].each do |env|
      config = queue_config(env)

      assert_in_delta 0.1, config["workers"].sole["polling_interval"], 0.001, env
      assert_equal 1, config["dispatchers"].sole["polling_interval"], env
    end
  end

  private

  def queue_config(env)
    YAML.safe_load(ERB.new(Rails.root.join("config/queue.yml").read).result, aliases: true)[env]
  end
end
