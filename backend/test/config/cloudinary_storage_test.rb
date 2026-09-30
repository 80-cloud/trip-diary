require "test_helper"

# 公開環境の画像は Cloudinary に置く (Issue #149)。
# 本番の設定はテストの環境では読まれないため、ファイルを読み直して確かめる。
class CloudinaryStorageTest < ActiveSupport::TestCase
  test "storage.yml の cloudinary は、このアプリ用のフォルダに保存し、接続情報を持たない" do
    config = load_storage_config.fetch("cloudinary", {})

    assert_equal "Cloudinary", config["service"]
    assert_equal "trip-diary", config["folder"]
    # 接続情報は環境変数 CLOUDINARY_URL を gem が読む
    assert_equal %w[folder service], config.keys.sort
  end

  test "storage.yml に S3 のサービスが残っていない" do
    config = load_storage_config

    assert_not config.key?("amazon")
    assert_not config.values.any? { |service| service["service"] == "S3" }
  end

  test "本番は Active Storage の保存先に Cloudinary を使う" do
    lines = Rails.root.join("config/environments/production.rb").readlines.map(&:strip)

    services = lines.select { |line| line.start_with?("config.active_storage.service") }

    assert_equal [ "config.active_storage.service = :cloudinary" ], services
  end

  test "Gemfile の cloudinary は production のグループだけに入り、aws-sdk-s3 は無い" do
    dependencies = Bundler.definition.dependencies.index_by(&:name)

    assert_equal [ :production ], dependencies["cloudinary"]&.groups
    assert_not dependencies.key?("aws-sdk-s3")
  end

  test "Gemfile.lock に cloudinary があり、aws-sdk-s3 は無い" do
    names = Bundler.locked_gems.specs.map(&:name).uniq

    assert_equal [ "cloudinary" ], names & %w[cloudinary aws-sdk-s3]
  end

  private

  def load_storage_config
    YAML.safe_load(ERB.new(Rails.root.join("config/storage.yml").read).result, aliases: true)
  end
end
