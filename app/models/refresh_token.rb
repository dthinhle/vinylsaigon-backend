# frozen_string_literal: true

# == Schema Information
#
# Table name: refresh_tokens
#
#  id           :bigint           not null, primary key
#  device_info  :string
#  expires_at   :datetime         not null
#  last_used_at :datetime
#  token        :string           not null
#  token_ip     :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_refresh_tokens_on_expires_at  (expires_at)
#  index_refresh_tokens_on_token       (token) UNIQUE
#  index_refresh_tokens_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class RefreshToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  before_validation :set_expiration, on: :create

  def friendly_device_info
    return 'Unknown Device' if device_info.blank?

    begin
      user_agent = UserAgentParser.parse(device_info)
      browser = "#{user_agent.name} #{user_agent.version}".strip
      os = "#{user_agent.os.name} #{user_agent.os.version}".strip
      device = user_agent.device.name

      parts = []
      parts << browser if browser.present? && browser != 'Other'
      parts << "on #{os}" if os.present? && os != 'Other'
      parts << "(#{device})" if device.present? && device != 'Other'

      parts.any? ? parts.join(' ') : 'Unknown Device'
    rescue StandardError => e
      Rails.logger.error "Failed to parse device info: #{e.message}"
      'Unknown Device'
    end
  end

  def device_type
    return 'desktop' if device_info.blank?

    begin
      user_agent = UserAgentParser.parse(device_info)
      device_name = user_agent.device.name&.downcase || ''

      return 'mobile' if device_name.include?('iphone') || device_name.include?('android')
      return 'tablet' if device_name.include?('ipad') || device_name.include?('tablet')

      'desktop'
    rescue StandardError
      'desktop'
    end
  end

  def expired?
    expires_at < Time.current
  end

  def self.cleanup_expired
    expired.destroy_all
  end

  private

  def set_expiration
    self.expires_at ||= 30.days.from_now
  end
end
