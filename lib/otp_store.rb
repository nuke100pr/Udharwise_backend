class OtpStore
  TTL_SECONDS = 600

  def self.write(email, code)
    if redis_enabled?
      redis.set(key_for(email), code, ex: TTL_SECONDS)
    else
      Rails.cache.write(key_for(email), code, expires_in: TTL_SECONDS.seconds)
    end
  end

  def self.read(email)
    if redis_enabled?
      redis.get(key_for(email))
    else
      Rails.cache.read(key_for(email))
    end
  end

  def self.clear(email)
    if redis_enabled?
      redis.del(key_for(email))
    else
      Rails.cache.delete(key_for(email))
    end
  end

  def self.key_for(email)
    "otp:#{email.to_s.strip.downcase}"
  end
  private_class_method :key_for

  def self.redis_enabled?
    ENV["REDIS_URL"].to_s.strip.present?
  end
  private_class_method :redis_enabled?

  def self.redis
    Redis.new(url: ENV.fetch("REDIS_URL"))
  end
  private_class_method :redis
end
