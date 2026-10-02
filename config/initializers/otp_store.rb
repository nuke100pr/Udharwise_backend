# Force-load OTP helper (plain Ruby class in lib/, via autoload_lib).
# Safe no-op reference so boot fails loudly if the file is missing.
Rails.application.config.to_prepare do
  OtpStore
end
