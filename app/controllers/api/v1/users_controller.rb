module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!

      def me
        render json: {
          id: current_user.id,
          email: current_user.email,
          handle: current_user.handle,
          phone: current_user.phone
        }
      end

      def search
        handle = params.require(:handle).to_s.strip.downcase.delete_prefix("@")
        users = ::User.where("handle ILIKE ?","%#{handle}%").where.not(id: current_user.id).limit(10)
        render json: users.as_json(only: [:id, :email, :handle])
      end
      
    end
  end
end
