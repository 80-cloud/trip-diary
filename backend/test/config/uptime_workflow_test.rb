require "test_helper"

# 公開デモの死活監視のワークフロー (Issue #153 / 公開デモ化計画書 P1-6)。
# ワークフローはテストの外で動くため、ファイルを読んで設定を確かめる。
class UptimeWorkflowTest < ActiveSupport::TestCase
  PATH = Rails.root.join("../.github/workflows/uptime.yml")

  setup do
    @source = PATH.exist? ? PATH.read : ""
    @workflow = YAML.safe_load(@source) || {}
    # YAML 1.1 では on: が true のキーとして読まれる
    @triggers = @workflow[true] || @workflow["on"] || {}
    @job = @workflow.fetch("jobs", {}).values.first || {}
  end

  test "1 時間ごとに、毎時 0 分を避けて動き、手動でも実行できる" do
    crons = Array(@triggers["schedule"]).map { |entry| entry["cron"] }
    assert_equal 1, crons.size

    minute, *rest = crons.first.to_s.split
    assert_includes 1..59, minute.to_i
    assert_equal %w[* * * *], rest
    assert @triggers.key?("workflow_dispatch")
  end

  test "権限は読み取りだけで、実行環境と時間の上限が決まっている" do
    assert_equal({ "contents" => "read" }, @workflow["permissions"])
    assert_equal "ubuntu-24.04", @job["runs-on"]
    assert_includes 1..15, @job["timeout-minutes"].to_i
  end

  test "公開 URL の変数が無いあいだは、ジョブを飛ばす" do
    assert_equal "vars.UPTIME_URL", @job["if"]
  end

  test "健康チェックの status と、DB を読む旅行一覧の両方を確かめる" do
    assert_includes @source, "/api/v1/health"
    assert_includes @source, "jq -r .status"
    assert_includes @source, "/api/v1/trips"
  end
end
