# frozen_string_literal: true

module WordpressMigration
  class LexicalImageMigratorService
    include Rails.application.routes.url_helpers

    def self.call(lexical_json_string)
      new(lexical_json_string).call
    end

    def initialize(lexical_json_string)
      @lexical_data = JSON.parse(lexical_json_string)
      @blob_cache = {}
    end

    def call
      migrate_images_in_node(@lexical_data['root'])
      @lexical_data
    end

    private

    def migrate_images_in_node(node)
      return unless node.is_a?(Hash)

      if node['type'] == 'image'
        migrate_image_node(node)
      end

      if node['children'].is_a?(Array)
        node['children'].each { |child| migrate_images_in_node(child) }
      end
    end

    def migrate_image_node(node)
      src = node['src']
      return unless src.present? && wordpress_url?(src)

      blob = download_and_attach_image(src)
      if blob
        node['src'] = rails_blob_url(blob, host: default_url_options[:host], protocol: default_url_options[:protocol])
      end
    rescue StandardError => e
      Rails.logger.error("[LexicalImageMigrator] Failed to migrate image #{src}: #{e.message}")
    end

    def wordpress_url?(url)
      url.match?(%r{3kshop\.vn/wp-content/uploads/})
    end

    def download_and_attach_image(url)
      return @blob_cache[url] if @blob_cache.key?(url)

      result = ImageUploadService.call(url: url)

      if result[:success]
        blob = result[:blob]
        @blob_cache[url] = blob
        blob
      else
        Rails.logger.error("[LexicalImageMigrator] Failed to download image: #{result[:error]}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("[LexicalImageMigrator] Error downloading #{url}: #{e.message}")
      nil
    end

    def default_url_options
      Rails.application.config.action_mailer.default_url_options
    end
  end
end
