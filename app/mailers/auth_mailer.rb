class AuthMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.auth_mailer.otp.subject
  #
  def otp(email, code)
    @code = code
    mail to: email, subject: "Your login code"
  end
end
