require "test_helper"

# F-GUEST-01: ゲストの画像の合計上限 (Issue #113)
# 旅行の画像・チケットのファイル・アバターを合わせて 5 枚まで。通常ユーザーには適用しない。
class Api::V1::GuestImageLimitTest < ActionDispatch::IntegrationTest
  setup do
    post "/api/v1/guest_login"
    @guest = User.find(JSON.parse(response.body).dig("user", "id"))
  end

  test "旅行の画像 5 枚を保存済みのゲストが、チケットのファイルで 6 枚目を送ると 422" do
    trip = create_trip(@guest, image_count: 5)

    assert_no_difference -> { Ticket.count } do
      post "/api/v1/trips/#{trip.id}/tickets", params: { kind: "train", file: upload }
    end
    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"], User::GUEST_IMAGE_LIMIT_ERROR
  end

  test "旅行の画像 5 枚を保存済みのゲストは、アバターを付けられない" do
    create_trip(@guest, image_count: 5)

    patch "/api/v1/me", params: { avatar: upload }
    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"], User::GUEST_IMAGE_LIMIT_ERROR
  end

  test "旅行の画像 4 枚とアバター 1 枚を保存済みなら、別の旅行に画像を付けられない" do
    create_trip(@guest, image_count: 4)
    @guest.update!(avatar: image(0))

    trip = build_trip(@guest, image_count: 1)
    assert_not trip.save
    assert_includes trip.errors.full_messages, User::GUEST_IMAGE_LIMIT_ERROR
  end

  test "1 つの旅行の画像 5 枚を 3 枚に置き換えるときは、置き換え後の枚数で数える" do
    trip = create_trip(@guest, image_count: 5)

    assert trip.update(images: images(3))
    assert_equal 3, trip.reload.images.count
  end

  test "通常ユーザーは、画像の合計が 5 枚を超えても保存できる" do
    user = users(:alice)
    create_trip(user, image_count: 5)

    assert build_trip(user, image_count: 1).save
  end

  private

  def image(number)
    { io: StringIO.new("image-#{number}"), filename: "photo#{number}.png", content_type: "image/png" }
  end

  def images(count)
    Array.new(count) { |number| image(number) }
  end

  def upload
    Rack::Test::UploadedFile.new(StringIO.new("image"), "image/png", original_filename: "photo.png")
  end

  def build_trip(user, image_count:)
    user.trips.new(title: "画像の旅", destination: "札幌",
                   started_on: "2026-08-01", ended_on: "2026-08-02",
                   category: "domestic", images: images(image_count))
  end

  def create_trip(user, image_count:)
    build_trip(user, image_count: image_count).tap(&:save!)
  end
end
