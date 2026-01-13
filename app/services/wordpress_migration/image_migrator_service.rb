# frozen_string_literal: true

module WordpressMigration
  class ImageMigratorService
    include Rails.application.routes.url_helpers

    def self.call(html)
      new(html).call
    end

    def initialize(html)
      @html = html
      @blob_cache = {}
    end

    def call
      return '' if @html.blank?

      doc = Nokogiri::HTML.fragment(@html)
      migrate_images(doc)
      doc.to_html
    end

    private

    def migrate_images(doc)
      doc.css('img').each do |img|
        src = img['src']
        next if src.blank?

        next unless should_migrate_image?(src)

        blob = download_and_attach_image(src)
        if blob
          img['src'] = rails_blob_url(blob, host: default_url_options[:host], protocol: default_url_options[:protocol])
        end
      rescue StandardError => e
        Rails.logger.error("[ImageMigrator] Failed to migrate image #{src}: #{e.message}")
      end
    end

    def should_migrate_image?(url)
      # Migrate all images except those already in Active Storage
      !url.include?('/rails/active_storage/')
    end

    def download_and_attach_image(url)
      return @blob_cache[url] if @blob_cache.key?(url)

      result = ImageUploadService.call(url: url)

      if result[:success]
        blob = result[:blob]
        @blob_cache[url] = blob
        blob
      else
        Rails.logger.error("[ImageMigrator] Failed to download image: #{result[:error]}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("[ImageMigrator] Error downloading #{url}: #{e.message}")
      nil
    end

    def default_url_options
      Rails.application.config.action_mailer.default_url_options
    end
  end
end
