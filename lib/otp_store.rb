class OtpStore
  TTL_SECONDS = 600

  def self.write(email, code)
    redis.set(key_for(email), code, ex: TTL_SECONDS)
  end

  def self.read(email)
    redis.get(key_for(email))
  end

  def self.clear(email)
    redis.del(key_for(email))
  end

  def self.key_for(email)
    "otp:#{email.to_s.strip.downcase}"
  end
  private_class_method :key_for

  def self.redis
    Redis.new(url: ENV.fetch("REDIS_URL"))
  end
  private_class_method :redis
end
