module Api
  class AuthController < Api::BaseController
    before_action :authenticate_user!, only: %i[log_out log_out_all_devices]
    rescue_from ActiveRecord::RecordNotFound, with: :handle_user_not_found

    def sign_in
      @user = find_user
      if @user.valid_password?(auth_params[:password])
        @cart = CartService.find_or_create_cart({ session_id: session_id, user_id: @user.id }) if session_id.present?
        set_tokens(@user)
      else
        render json: { success: false, error: APIError::INVALID_CREDENTIAL }, status: :unprocessable_entity
      end
    end

    def sign_up
      email, password = auth_params.values_at(:email, :password)

      @user = User.new(email:, password:)
      if @user.valid? && @user.save
        set_tokens(@user)
      else
        render json: { success: false, error: @user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def refresh_token
      @user, refresh_token_record = find_user_by_refresh_token
      if @user && refresh_token_record
        set_tokens(@user, refresh_token_record: refresh_token_record)
      else
        render json: { success: false, error: 'Invalid or expired refresh token' }, status: :unprocessable_entity
      end
    end

    def log_out
      token = params[:refresh_token]
      result = token.present? ? @user.clear_token(token) : nil
      if result && result.destroyed?
        render json: { success: true }, status: :ok
      else
        render json: { success: false, error: 'Invalid refresh token' }, status: :unprocessable_entity
      end
    end

    def log_out_all_devices
      if @user.clear_tokens
        render json: { success: true }, status: :ok
      else
        render json: { success: false, error: @user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def forgot_password
      email = forgot_password_params[:email]

      # Use Devise's built-in method to send reset password instructions
      # This method handles token generation, saving, and email sending automatically
      user = User.send_reset_password_instructions(email: email)

      if user.errors.empty?
        render json: {
          success: true,
          message: 'Password reset instructions have been sent to your email'
        }, status: :ok
      else
        # Don't reveal if email exists or not for security
        render json: {
          success: true,
          message: 'If an account with that email exists, password reset instructions have been sent'
        }, status: :ok
      end
    rescue StandardError => e
      Rails.logger.error "Forgot password error: #{e.message}"
      render json: {
        success: false,
        error: 'Unable to process password reset request'
      }, status: :unprocessable_entity
    end

    def reset_password
      token = reset_password_params[:reset_password_token]
      password = reset_password_params[:password]
      password_confirmation = reset_password_params[:password_confirmation]

      user = User.reset_password_by_token({
        reset_password_token: token,
        password: password,
        password_confirmation: password_confirmation
      })

      if user.errors.empty?
        # Clear tokens to force re-login
        user.clear_tokens if user.respond_to?(:clear_tokens)

        render json: {
          success: true,
          message: 'Password has been reset successfully'
        }, status: :ok
      else
        render json: {
          success: false,
          error: user.errors.full_messages.first
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Reset password error: #{e.message}"
      render json: {
        success: false,
        error: 'Unable to reset password'
      }, status: :unprocessable_entity
    end

    def verify_reset_password_token
      token = verify_token_params[:reset_password_token]

      if token.blank?
        render json: {
          success: false,
          error: 'Reset password token is required'
        }, status: :unprocessable_entity
        return
      end

      # Use Devise's method to find user by reset password token without resetting
      user = User.with_reset_password_token(token)

      if user && user.reset_password_period_valid?
        render json: {
          success: true,
          message: 'Token is valid',
          data: {
            email: user.email # Return masked email for user confirmation
          }
        }, status: :ok
      else
        render json: {
          success: false,
          error: 'Invalid or expired reset password token'
        }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "Verify reset password token error: #{e.message}"
      render json: {
        success: false,
        error: 'Unable to verify reset password token'
      }, status: :unprocessable_entity
    end

    def handle_user_not_found(exception)
      render json: { success: false, error: APIError::INVALID_CREDENTIAL }, status: :unprocessable_entity
    end

    private

    def set_tokens(user, refresh_token_record: nil)
      if refresh_token_record.nil? && user.refresh_tokens.active.empty?
        user.update!(jti: SecureRandom.uuid)
      end

      @access_token = user.access_token_data[:token]
      @exp = user.access_token_data.dig(:response, :exp)

      @refresh_token =
        if refresh_token_record
          refresh_token_record.update!(last_used_at: Time.current)
          refresh_token_record.token
        else
          user.generate_refresh_token(
            token_ip: request.remote_ip,
            device_info: request.user_agent
          )
        end
    end

    def find_user
      user = User.find_by(email: auth_params[:email])
      raise ActiveRecord::RecordNotFound if user.nil?

      user
    end

    def find_user_by_refresh_token
      token = refresh_token_params[:refresh_token]
      refresh_token_record = RefreshToken.find_by(token: token)

      return [nil, nil] if refresh_token_record.nil? || refresh_token_record.expired?

      user = refresh_token_record.user
      raise ActiveRecord::RecordNotFound if user.nil?

      [user, refresh_token_record]
    rescue StandardError
      [nil, nil]
    end

    def auth_params
      @auth_params ||= begin
        permitted_params = params.permit(:email, :password)
        raise 'Missing email or password' if permitted_params[:email].blank? || permitted_params[:password].blank?

        permitted_params
      end
    end


    def refresh_token_params
      params.permit(:refresh_token)
    end

    def forgot_password_params
      params.permit(:email)
    end

    def reset_password_params
      params.permit(:reset_password_token, :password, :password_confirmation)
    end

    def verify_token_params
      params.permit(:reset_password_token)
    end

    def session_id
      request.headers['X-Session-ID']
    end
  end
end
