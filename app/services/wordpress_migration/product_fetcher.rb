# frozen_string_literal: true

module WordpressMigration
  class ProductFetcher
    MAX_PER_PAGE = 50

    def initialize(api_client = nil, cache_responses: false)
      @api_client = api_client || ApiClient.new
      @cache_responses = cache_responses
      @cache_dir = Rails.root.join('tmp', 'wordpress_api_cache')
      FileUtils.mkdir_p(@cache_dir) if @cache_responses
    end

    def fetch_all(per_page: MAX_PER_PAGE)
      per_page = [per_page, MAX_PER_PAGE].min

      Rails.logger.info('Fetching products from WordPress API...')

      products = []
      page = 1

      loop do
        result = fetch_batch(page: page, per_page: per_page)
        batch = result[:products]

        break if batch.nil? || batch.empty?

        products.concat(batch)
        Rails.logger.info("Fetched #{batch.size} products (page #{page}, total: #{products.size})")

        total_pages = result[:total_pages]
        break if total_pages && page >= total_pages

        page += 1
        sleep 0.2
      end

      Rails.logger.info("Completed fetching #{products.size} products from WordPress API")
      products
    rescue ApiClient::ApiError => e
      Rails.logger.error("Failed to fetch products from WordPress API: #{e.message}")
      raise
    end

    def fetch_batch(page:, per_page: MAX_PER_PAGE)
      per_page = [per_page, MAX_PER_PAGE].min

      Rails.logger.info("Fetching products page #{page} (per_page: #{per_page})...")

      if @cache_responses && (cached_file = @cache_dir.join("products-page-#{page}-per_page-#{per_page}.json")).exist?
        Rails.logger.info("Loading cached products from #{cached_file}")
        cached = JSON.parse(File.read(cached_file))

        # Support several cache formats:
        # - Array of products (legacy)
        # - Hash of { data: [...], headers: {...} } (current)
        # - Hash with 'products' key
        # - Hash with nested 'response' => { 'data' => [...], 'headers' => {...} }
        products_from_cache =
          if cached.is_a?(Array)
            cached
          elsif cached.is_a?(Hash) && cached['data']
            cached['data'].is_a?(Array) ? cached['data'] : [cached['data']]
          elsif cached.is_a?(Hash) && cached['products']
            cached['products'].is_a?(Array) ? cached['products'] : [cached['products']]
          elsif cached.is_a?(Hash) && cached['response'] && cached['response']['data']
            cached['response']['data'].is_a?(Array) ? cached['response']['data'] : [cached['response']['data']]
          else
            []
          end

        headers =
          if cached.is_a?(Hash)
            cached['headers'] || (cached['response'].is_a?(Hash) && cached['response']['headers']) || {}
          else
            {}
          end

        # Normalize header keys to be lowercase strings for robust lookup
        normalized_headers = {}
        if headers.is_a?(Hash)
          headers.each do |k, v|
            normalized_headers[k.to_s.downcase] = v if k
          end
        end

        Rails.logger.info("Loaded headers: #{normalized_headers}")
        total_pages_from_cache = Array.wrap(normalized_headers['x-wp-totalpages']).first
        total_count_from_cache = Array.wrap(normalized_headers['x-wp-total']).first

        return {
          products: products_from_cache,
          total_pages: total_pages_from_cache,
          total_count: total_count_from_cache,
          current_page: page
        }
      end

      response = @api_client.get('/products', { page: page, per_page: per_page })

      cache_response('products', page, per_page, response) if @cache_responses

      {
        products: response[:data],
        total_pages: response[:headers]['x-wp-totalpages']&.to_i,
        total_count: response[:headers]['x-wp-total']&.to_i,
        current_page: page
      }
    rescue ApiClient::ApiError => e
      Rails.logger.error("Failed to fetch products page #{page}: #{e.message}")
      raise
    end

    private

    def cache_response(resource, page, per_page, response)
      filename = "#{resource}-page-#{page}-per_page-#{per_page}.json"
      filepath = @cache_dir.join(filename)
      content = { data: response[:data], headers: response[:headers] }
      File.write(filepath, JSON.pretty_generate(content))
      Rails.logger.info("Cached response to #{filepath}")
    end
  end
end
