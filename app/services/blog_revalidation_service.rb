# frozen_string_literal: true

class BlogRevalidationService
  def initialize
    @auth_token = ENV['REVALIDATION_SECRET']
  end

  def self.revalidate_all_blogs
    new.revalidate_all_blogs
  end

  def self.revalidate_blog(slug)
    new.revalidate_specific_blog(slug)
  end

  def revalidate_blog(slug: nil, type: 'specific')
    return false if skip_revalidation?

    begin
      url = "#{ENV['FRONTEND_HOST']}/api/revalidate-blog"

      response = HTTParty.post(url, {
        headers: headers,
        body: { slug: slug, type: type }.to_json
      })

      if response.success?
        Rails.logger.info "✅ Successfully revalidated blog cache: #{slug || 'all blogs'}"
        true
      else
        Rails.logger.warn "⚠️ Failed to revalidate blog cache: #{response.code} - #{response.message}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "❌ Error revalidating blog cache: #{e.message}"
      false
    end
  end

  def revalidate_specific_blog(slug)
    revalidate_blog(slug: slug, type: 'specific')
  end

  def revalidate_all_blogs
    revalidate_blog(type: 'all')
  end

  private

  def headers
    headers = { 'Content-Type' => 'application/json' }
    headers['Authorization'] = "Bearer #{@auth_token}" if @auth_token.present?
    headers
  end

  def skip_revalidation?
    # Skip in test environment or when frontend URL is not configured
    Rails.env.test? || (ENV['FRONTEND_HOST'].blank?)
  end
end
