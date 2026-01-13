# frozen_string_literal: true

module WordpressMigration
  class CategoryFetcher
    def initialize(api_client = nil, cache_responses: false)
      @api_client = api_client || ApiClient.new
      @cache_responses = cache_responses
      @cache_dir = Rails.root.join('tmp', 'wordpress_api_cache')
      FileUtils.mkdir_p(@cache_dir) if @cache_responses
    end

    def fetch_all
      Rails.logger.info('Fetching categories from WordPress API...')

      categories = []
      page = 1
      per_page = 100

      loop do
        response = @api_client.get('/products/categories', { page: page, per_page: per_page })
        batch = response[:data]

        cache_response('categories', page, per_page, response) if @cache_responses

        break if batch.empty?

        categories.concat(batch)
        Rails.logger.info("Fetched #{batch.size} categories (page #{page}, total: #{categories.size})")

        total_pages = response[:headers]['x-wp-totalpages']&.to_i
        break if total_pages && page >= total_pages

        page += 1
        sleep 0.1
      end

      Rails.logger.info("Completed fetching #{categories.size} categories from WordPress API")
      categories
    rescue ApiClient::ApiError => e
      Rails.logger.error("Failed to fetch categories from WordPress API: #{e.message}")
      raise
    end

    private

    def cache_response(resource, page, per_page, response)
      filename = "#{resource}-page-#{page}-per_page-#{per_page}.json"
      filepath = @cache_dir.join(filename)
      File.write(filepath, JSON.pretty_generate(response[:data]))
      Rails.logger.info("Cached response to #{filepath}")
    end
  end
end
