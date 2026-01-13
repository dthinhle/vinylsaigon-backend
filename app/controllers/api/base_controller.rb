# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    rescue_from OrderCreatorService::InvalidPromotionCombinationError do |exception|
      render json: {
        error: 'Invalid promotion combination',
        message: exception.message
      }, status: :unprocessable_entity
    end

    rescue_from StandardError do |exception|
      render_error_response(APIError::CANNOT_PROCESS_REQUEST, exception)
    end

    rescue_from ::Error::AuthorizationError do |exception|
      render_error_response(APIError::AUTH_HEADER_MISSING, exception)
    end

    rescue_from JWT::ExpiredSignature do |exception|
      render_error_response(APIError::SIGNATURE_EXPIRED, exception)
    end

    private

    def render_error_response(error_message, exception)
      Bugsnag.notify(exception) if defined?(Bugsnag)

      response = { error: error_message, message: exception.message }
      response[:backtrace] = exception.backtrace if Rails.env.local?

      Rails.logger.error("[API Error] #{exception.class}: #{exception.message}\n#{exception.backtrace.join("\n")}")

      render json: response, status: :unprocessable_entity
    end

    def authenticate_user!
      authorization_header = request.authorization
      raise ::Error::AuthorizationError if authorization_header.blank?

      _method, token = authorization_header.split
      response = Warden::JWTAuth::TokenDecoder.new.call(token)
      user_id = response['sub']

      @user = User.find(user_id)
    end

    def authenticate_user
      authorization_header = request.authorization
      return if authorization_header.blank?

      parts = authorization_header.split
      return if parts.length < 2

      _method, token = parts
      return if token.blank?

      begin
        response = Warden::JWTAuth::TokenDecoder.new.call(token)
        user_id = response['sub']
        @user = User.find_by(id: user_id)
      rescue JWT::DecodeError, JWT::VerificationError
        # Invalid token, but this is optional auth so just return
        nil
      end
    end
  end
end
