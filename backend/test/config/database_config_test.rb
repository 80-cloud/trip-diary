require "test_helper"

# 公開環境の DB (TiDB Cloud Starter) は TLS の接続だけを受け付ける (Issue #143)。
# MYSQL_SSL_MODE で database.yml の ssl_mode を切り替え、未設定なら手元の MySQL と同じ接続のままにする。
class DatabaseConfigTest < ActiveSupport::TestCase
  ENVS = %w[development test production].freeze

  setup do
    @original = ENV["MYSQL_SSL_MODE"]
  end

  teardown do
    ENV["MYSQL_SSL_MODE"] = @original
  end

  test "MYSQL_SSL_MODE があれば、3 つの環境すべてに ssl_mode が入る" do
    ENV["MYSQL_SSL_MODE"] = "verify_identity"

    ENVS.each { |env| assert_equal "verify_identity", db_config(env)["ssl_mode"], env }
  end

  test "MYSQL_SSL_MODE が無ければ、ssl_mode は入らない" do
    ENV["MYSQL_SSL_MODE"] = nil

    ENVS.each { |env| assert_nil db_config(env)["ssl_mode"], env }
  end

  private

  # 起動時に読んだ設定ではなく、今の ENV で database.yml を評価し直す
  def db_config(env)
    config = YAML.safe_load(ERB.new(Rails.root.join("config/database.yml").read).result, aliases: true)[env]
    config.key?("primary") ? config["primary"] : config
  end
end
