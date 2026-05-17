# SimpleCov はカバレッジ計測のため、アプリのコードを require する**前**に start する必要がある。
# (test_helper.rb の最先頭に置くこと — `ENV["RAILS_ENV"]` よりも前)
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter %w[/test/ /config/ /db/ /vendor/ /bin/]
  add_group "Controllers", "app/controllers"
  add_group "Models",      "app/models"
  add_group "Services",    "app/services"
  # TODO: parallelize(workers: N>1) にする際は SimpleCov.command_name と
  # parallelize_setup/teardown を追加して結果マージを行うこと。
  # (現状は workers=1 固定なので衝突しない)
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # MySQL fixture との相性で初期は単一プロセス。
    # CI が安定したら parallelize(workers: :number_of_processors) に上げて良い。
    parallelize(workers: 1)

    fixtures :all
  end
end

module ActionDispatch
  class IntegrationTest
    # 本物の login 経路を通して JWT Cookie を発行する。
    # `cookies.encrypted[]=` を直接埋める方式は cookie serializer の
    # 整合性で罠が多いため、テストでは必ずこのヘルパー経由で認証する。
    def login_via_api(user, password = "password123")
      post "/api/v1/login", params: { email: user.email, password: password }
      assert_response :ok, "login_via_api failed for #{user.email}"
    end
  end
end
