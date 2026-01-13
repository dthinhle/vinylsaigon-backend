# frozen_string_literal: true

class ProductRevalidationService
  def initialize
    @auth_token = ENV['REVALIDATION_SECRET']
  end

  def self.revalidate_products
    new.revalidate_all_products
  end

  def self.revalidate_specific_product(slug)
    new.revalidate_specific_product(slug)
  end

  def revalidate_product(slug: nil, type: 'specific')
    return false if skip_revalidation?

    begin
      url = "#{ENV['FRONTEND_HOST']}/api/revalidate-product"

      response = HTTParty.post(url, {
        headers: headers,
        body: { slug: slug, type: type }.to_json
      })

      if response.success?
        Rails.logger.info "✅ Successfully revalidated product cache: #{slug || 'all products'}"
        true
      else
        Rails.logger.warn "⚠️ Failed to revalidate product cache: #{response.code} - #{response.message}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "❌ Error revalidating product cache: #{e.message}"
      false
    end
  end

  def revalidate_specific_product(slug)
    revalidate_product(slug: slug, type: 'specific')
  end

  def revalidate_all_products
    revalidate_product(type: 'all')
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
