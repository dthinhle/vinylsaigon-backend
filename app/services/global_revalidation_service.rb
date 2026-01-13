# frozen_string_literal: true

class GlobalRevalidationService
  def initialize
    @auth_token = ENV['REVALIDATION_SECRET']
  end

  def self.revalidate_redirections
    new.revalidate_resources('redirections')
  end

  def self.revalidate_menu
    new.revalidate_resources('menu')
  end

  def revalidate_resources(resource_slug)
    return false if skip_revalidation?

    begin
      url = "#{ENV['FRONTEND_HOST']}/api/revalidate-#{resource_slug}"

      response = HTTParty.post(url, {
        headers: headers,
        body: {}.to_json
      })

      if response.success?
        Rails.logger.info "GlobalRevalidationService revalidate_#{resource_slug}: Successfully revalidated #{resource_slug} cache"
        true
      else
        Rails.logger.warn "GlobalRevalidationService revalidate_#{resource_slug}: Failed to revalidate #{resource_slug} cache: #{response.code} - #{response.message}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "GlobalRevalidationService revalidate_#{resource_slug}: Error revalidating #{resource_slug} cache: #{e.message}"
      false
    end
  end

  private

  def headers
    headers = { 'Content-Type' => 'application/json' }
    headers['Authorization'] = "Bearer #{@auth_token}" if @auth_token.present?
    headers
  end

  def skip_revalidation?
    Rails.env.test? || ENV['FRONTEND_HOST'].blank?
  end
end
