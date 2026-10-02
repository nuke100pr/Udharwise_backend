class JsonWebToken
  def self.encode(payload,exp:24.hours.from_now)
    payload = payload.dup
    payload[:exp] = exp.to_i
    JWT.encode(payload,ENV.fetch("JWT_SECRET"),"HS256")
  end
  
  def self.decode(token)
    body = JWT.decode(token,ENV.fetch("JWT_SECRET"),true,{algorithm:"HS256"}).first
    HashWithIndifferentAccess.new body
  rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError
    nil
  end
end
