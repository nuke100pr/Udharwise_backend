require "test_helper"

class AuthMailerTest < ActionMailer::TestCase
  test "otp" do
    mail = AuthMailer.otp
    assert_equal "Otp", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
