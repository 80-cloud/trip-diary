require "test_helper"

# F-GUEST-01: ゲストユーザーの作成・期限・後片付け (Issue #109)
class UserGuestTest < ActiveSupport::TestCase
  test "create_guest! は guest: true のユーザーを架空のアドレスと表示名で作る" do
    guest = User.create_guest!

    assert guest.persisted?
    assert guest.guest?
    assert guest.email.end_with?("@example.invalid"), guest.email
    assert_match(/\Aゲスト-\d{4}\z/, guest.display_name)
  end

  test "通常のユーザーは guest: false" do
    assert_not users(:alice).guest?
  end

  test "active_guests は作成から 24 時間以内のゲストだけを返す" do
    old_guest = User.create_guest!
    travel 25.hours
    new_guest = User.create_guest!

    assert_includes User.active_guests, new_guest
    assert_not_includes User.active_guests, old_guest
    assert_includes User.expired_guests, old_guest
    assert_not_includes User.active_guests, users(:alice)
  end

  test "cleanup_expired_guests! は期限切れのゲストを最大 20 人ずつ削除する" do
    21.times { User.create_guest! }
    travel 25.hours
    active = User.create_guest!

    assert_equal 20, User.cleanup_expired_guests!
    assert_equal 1, User.expired_guests.count
    assert User.exists?(active.id)
    assert User.exists?(users(:alice).id)
  end

  test "demo_users は @demo.example.com のユーザーを id の小さい順に返す" do
    demo_b = create_demo_user("kenta")
    demo_a = create_demo_user("sakura")
    User.create!(email: "x@demo.example.com.test", password: "password123", display_name: "X")

    assert_equal [ demo_b, demo_a ], User.demo_users.to_a
  end

  private

  def create_demo_user(key)
    User.create!(email: "#{key}@#{User::DEMO_EMAIL_DOMAIN}", password: "password123", display_name: key)
  end
end
