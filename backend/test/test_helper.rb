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
