module Api
  module V1
    module Auth
      class SessionsController < ApplicationController
        include AuthenticatesWithJwt

        def create
          handle = params.require(:handle).to_s.strip.downcase.delete_prefix("@")
          password = params.require(:password).to_s

          user = ::User.find_by(handle: handle)
          unless user&.password_set? && user.authenticate(password)
            return render json: { error: "invalid_credentials" }, status: :unauthorized
          end

          render_auth_success(user)
        end
      end
    end
  end
end
