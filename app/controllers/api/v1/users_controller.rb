module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!

      def me
        render json: serialize_user(current_user)
      end

      def update
        attrs = {}
        attrs[:email] = params[:email] if params.key?(:email)
        attrs[:phone] = params[:phone] if params.key?(:phone)

        if attrs.empty?
          return render json: { error: "nothing_to_update" }, status: :unprocessable_entity
        end

        if current_user.update(attrs)
          render json: serialize_user(current_user)
        else
          render json: { error: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def search
        handle = params.require(:handle).to_s.strip.downcase.delete_prefix("@")
        users = ::User.where("handle ILIKE ?", "%#{handle}%").where.not(id: current_user.id).limit(10)
        render json: users.as_json(only: [:id, :email, :handle])
      end

      private

      def serialize_user(user)
        {
          id: user.id,
          email: user.email,
          handle: user.handle,
          phone: user.phone
        }
      end
    end
  end
end
