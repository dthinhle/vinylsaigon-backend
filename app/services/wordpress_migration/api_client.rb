# frozen_string_literal: true

module WordpressMigration
  class ApiClient
    class ApiError < StandardError; end
    class AuthenticationError < ApiError; end
    class NotFoundError < ApiError; end

    include HTTParty
    base_uri ENV.fetch('WORDPRESS_SITE_HOST', 'https://3kshop.vn') + '/wp-json/wc/v3'
    basic_auth ENV.fetch('WORDPRESS_API_USERNAME', ''), ENV.fetch('WORDPRESS_API_PASSWORD', '')
    format :json

    def initialize
      @host = ENV.fetch('WORDPRESS_SITE_HOST', 'https://3kshop.vn')
      @username = ENV.fetch('WORDPRESS_API_USERNAME', '')
      @password = ENV.fetch('WORDPRESS_API_PASSWORD', '')
      @base_url = "#{@host}/wp-json/wc/v3"
    rescue KeyError => e
      raise ApiError, "Missing required environment variable: #{e.message}"
    end

    def get(endpoint, params = {})
      response = self.class.get(endpoint, query: params)

      handle_response(response)
    end

    private

    def handle_response(response)
      case response.code
      when 200..299
        {
          data: response.parsed_response,
          headers: response.headers
        }
      when 401
        raise AuthenticationError, "WordPress API authentication failed: #{response.message}"
      when 404
        raise NotFoundError, "WordPress API endpoint not found: #{response.message}"
      else
        raise ApiError, "WordPress API request failed (#{response.code}): #{response.message}"
      end
    end
  end
end
