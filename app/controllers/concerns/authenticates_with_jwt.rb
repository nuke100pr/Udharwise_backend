module AuthenticatesWithJwt
  extend ActiveSupport::Concern

  private

  def render_auth_success(user)
    expires_at = 1.day.from_now
    token = ::JsonWebToken.encode({ user_id: user.id }, exp: expires_at)

    render json: {
      token: token,
      expires_at: expires_at.iso8601,
      expires_in: 1.day.to_i,
      user: {
        id: user.id,
        email: user.email,
        handle: user.handle,
        phone: user.phone
      }
    }, status: :ok
  end
end
