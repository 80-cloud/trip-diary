require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is required" do
    user = User.new(password: "password123", display_name: "Test")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "bio は 500 文字以内" do
    u = users(:alice)
    u.bio = "a" * 500
    assert u.valid?
    u.bio = "a" * 501
    refute u.valid?
  end

  test "avatar: 2MB 超は invalid" do
    u = users(:alice)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x" * (User::AVATAR_MAX_SIZE + 1)),
      filename: "big.jpg",
      content_type: "image/jpeg"
    )
    u.avatar.attach(blob)
    refute u.valid?
    assert u.errors[:avatar].any?
  end

  test "avatar: 非対応 content_type は invalid" do
    u = users(:alice)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("dummy"),
      filename: "bad.bmp",
      content_type: "image/bmp"
    )
    u.avatar.attach(blob)
    refute u.valid?
    assert u.errors[:avatar].any?
  end

  test "avatar: PNG は valid" do
    u = users(:alice)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("dummy"),
      filename: "ok.png",
      content_type: "image/png"
    )
    u.avatar.attach(blob)
    assert u.valid?
  end
end
