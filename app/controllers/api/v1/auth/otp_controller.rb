module Api
  module V1
    module Auth
      class OtpController < ApplicationController
        def request_otp
          email = params.require(:email).to_s.strip.downcase
          code = SecureRandom.random_number(10**6).to_s.rjust(6, "0")

          ::OtpStore.write(email, code)
          ::AuthMailer.otp(email, code).deliver_later

          render json: { message: "otp_sent" }, status: :ok
        end

        def verify
          email = params.require(:email).to_s.strip.downcase
          code = params.require(:code).to_s.strip

          stored = ::OtpStore.read(email)
          valid = stored.present? &&
                  stored.bytesize == code.bytesize &&
                  ActiveSupport::SecurityUtils.secure_compare(stored, code)
          unless valid
            return render json: { error: "invalid_otp" }, status: :unauthorized
          end

          user = ::User.find_by(email: email)

          if user.nil?
            phone = params[:phone].to_s.strip
            handle = params[:handle].to_s.strip.downcase.delete_prefix("@")

            if phone.blank? || handle.blank?
              # Keep OTP so client can retry verify with phone + handle
              return render json: {
                error: "onboarding_required",
                required: %w[phone handle],
                message: "New user — call verify again with the same code, plus phone and handle"
              }, status: :unprocessable_entity
            end

            user = ::User.create!(email: email, phone: phone, handle: handle)
          end

          ::OtpStore.clear(email)
          token = ::JsonWebToken.encode({ user_id: user.id })

          render json: {
            token: token,
            user: {
              id: user.id,
              email: user.email,
              handle: user.handle,
              phone: user.phone
            }
          }, status: :ok
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end
end
