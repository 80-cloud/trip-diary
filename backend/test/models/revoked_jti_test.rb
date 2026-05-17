require "test_helper"

class RevokedJtiTest < ActiveSupport::TestCase
  test "jti と expires_at は必須" do
    refute RevokedJti.new(jti: nil, expires_at: 1.day.from_now).valid?
    refute RevokedJti.new(jti: SecureRandom.uuid, expires_at: nil).valid?
    assert RevokedJti.new(jti: SecureRandom.uuid, expires_at: 1.day.from_now).valid?
  end

  test "active scope は expires_at > now のみ" do
    fresh    = RevokedJti.create!(jti: SecureRandom.uuid, expires_at: 1.day.from_now)
    expired  = RevokedJti.create!(jti: SecureRandom.uuid, expires_at: 1.minute.ago)
    assert_includes RevokedJti.active.pluck(:jti), fresh.jti
    refute_includes RevokedJti.active.pluck(:jti), expired.jti
  end

  test "revoke! は idempotent (同 jti 2 回でも 1 行)" do
    jti = SecureRandom.uuid
    exp = 1.day.from_now
    assert_difference -> { RevokedJti.count }, 1 do
      RevokedJti.revoke!(jti: jti, expires_at: exp)
    end
    assert_no_difference -> { RevokedJti.count } do
      RevokedJti.revoke!(jti: jti, expires_at: exp)
    end
  end

  test "revoke! は nil / 空文字なら no-op" do
    assert_no_difference -> { RevokedJti.count } do
      RevokedJti.revoke!(jti: nil, expires_at: 1.day.from_now)
      RevokedJti.revoke!(jti: "", expires_at: 1.day.from_now)
      RevokedJti.revoke!(jti: SecureRandom.uuid, expires_at: nil)
    end
  end

  test "cleanup_expired! は expired のみ削除" do
    fresh   = RevokedJti.create!(jti: SecureRandom.uuid, expires_at: 1.day.from_now)
    expired = RevokedJti.create!(jti: SecureRandom.uuid, expires_at: 1.minute.ago)
    assert_difference -> { RevokedJti.count }, -1 do
      RevokedJti.cleanup_expired!
    end
    assert RevokedJti.exists?(fresh.jti)
    refute RevokedJti.exists?(expired.jti)
  end
end
