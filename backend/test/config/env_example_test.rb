require "test_helper"

# 公開環境で設定する変数を .env.example に書いておく (Issue #151)。
# 手元では有効にしないため、どれもコメントとして書き、値は書かない。
# 使わなくなった変数は書かない (TRUST_FIRST_FORWARDED_IP は Issue #158 で廃止)。
class EnvExampleTest < ActiveSupport::TestCase
  PUBLIC_VARIABLES = %w[
    SOLID_QUEUE_IN_PUMA
    SIGNUP_ENABLED
    DEMO_SEED_CONFIRM
    CLOUDINARY_URL
    NUXT_PUBLIC_SIGNUP_ENABLED
  ].freeze

  RETIRED_VARIABLES = %w[
    TRUST_FIRST_FORWARDED_IP
  ].freeze

  test ".env.example に公開環境の変数が、コメントとして書かれている" do
    lines = Rails.root.join("../.env.example").readlines.map(&:strip)

    PUBLIC_VARIABLES.each do |name|
      assert lines.any? { |line| line.start_with?("# #{name}=") }, name
    end
  end

  test ".env.example に、使わなくなった変数が書かれていない" do
    text = Rails.root.join("../.env.example").read

    RETIRED_VARIABLES.each do |name|
      assert_not_includes text, name
    end
  end
end
