class ApplicationController < ActionController::API
  def current_user
    return @current_user if defined?(@current_user)

    header = request.headers["Authorization"].to_s
    token = header.split.last
    payload = token.present? ? ::JsonWebToken.decode(token) : nil
    @current_user = payload ? ::User.find_by(id: payload[:user_id]) : nil
  end

  def authenticate_user!
    return if current_user

    render json: { error: "unauthorized" }, status: :unauthorized
  end
end
