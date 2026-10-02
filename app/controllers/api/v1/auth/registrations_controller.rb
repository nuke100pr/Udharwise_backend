module Api
  module V1
    module Auth
      class RegistrationsController < ApplicationController
        include AuthenticatesWithJwt

        def create
          user = ::User.new(
            email: params.require(:email),
            phone: params.require(:phone),
            handle: params.require(:handle),
            password: params.require(:password)
          )

          if user.save(context: :signup)
            render_auth_success(user)
          else
            render json: { error: user.errors.full_messages }, status: :unprocessable_entity
          end
        rescue ActionController::ParameterMissing => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
    end
  end
end
