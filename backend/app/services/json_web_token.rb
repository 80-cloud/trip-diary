require "jwt"

class JsonWebToken
  ALGORITHM = "HS256".freeze
  DEFAULT_EXP = 1.day

  class << self
    def encode(payload, exp: DEFAULT_EXP.from_now)
      payload = payload.dup
      payload[:exp] = exp.to_i
      JWT.encode(payload, secret, ALGORITHM)
    end

    def decode(token)
      decoded = JWT.decode(token, secret, true, algorithm: ALGORITHM).first
      HashWithIndifferentAccess.new(decoded)
    rescue JWT::DecodeError
      nil
    end

    private

    def secret
      ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
    end
  end
end
