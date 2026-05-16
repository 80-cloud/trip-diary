require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is required" do
    user = User.new(password: "password123", display_name: "Test")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end
end
