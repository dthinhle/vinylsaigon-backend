# frozen_string_literal: true

require 'active_support/concern'

# TODO: Drop the old refresh_token column from users table after ensuring all existing tokens have expired
module JwtAuthable
  REFRESH_TOKEN_EXPIRE_DAYS_COUNT = 7

  def access_token_data
    token, response = Warden::JWTAuth::UserEncoder.new.call(self, :user, FRONTEND_HOST)
    { token:, response: response.with_indifferent_access }
  end

  def generate_refresh_token(token_ip: nil, device_info: nil)
    token = SecureRandom.hex(32)
    refresh_tokens.create!(
      token:,
      token_ip:,
      device_info:,
      expires_at:   REFRESH_TOKEN_EXPIRE_DAYS_COUNT.days.from_now,
      last_used_at: Time.current,
    )
    token
  end

  def clear_tokens(current_token: nil)
    if current_token.nil?
      # Clear all refresh tokens
      refresh_tokens.destroy_all
      update(jti: nil)
    else
      # Clear all refresh tokens except the current one
      refresh_tokens.where.not(token: current_token).destroy_all
    end
  end

  def clear_token(token_string)
    # Clear a specific refresh token
    refresh_tokens.find_by(token: token_string)&.destroy
  end

  def jwt_subject
    id
  end

  def jwt_payload
    { 'jti' => jti }
  end
end
