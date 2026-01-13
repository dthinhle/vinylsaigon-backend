# frozen_string_literal: true

module WordpressMigration
  class LexicalLinkMigratorService
    BRAND_PREFIX = '/thuong-hieu'
    NEWS_PREFIX = '/tin-tuc'

    class << self
      def call(record:, content_field: :content)
        new(record: record, content_field: content_field).call
      end
    end

    def initialize(record:, content_field:)
      @record = record
      @content_field = content_field
      @links_migrated = 0
      @links_skipped = 0
      @brand_slugs = nil
      @blog_slugs = nil
    end

    def call
      content = @record.public_send(@content_field)
      return { success: true, migrated: 0, skipped: 0 } if content.blank? || !content.is_a?(Hash)

      root = content['root']
      return { success: true, migrated: 0, skipped: 0 } unless root

      # Load all brand and blog slugs once for efficient lookup
      load_slugs

      process_node(root)

      if @links_migrated > 0
        @record.update_column(@content_field, content)
      end

      log_result

      { success: true, migrated: @links_migrated, skipped: @links_skipped }
    rescue StandardError => e
      Rails.logger.error("[LexicalLinkMigrator] #{record_identifier} Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { success: false, error: e.message }
    end

    private

    def process_node(node)
      return unless node.is_a?(Hash)

      case node['type']
      when 'link'
        process_link_node(node)
      end

      process_children(node)
    end

    def process_children(node)
      return unless node['children'].is_a?(Array)

      node['children'].each { |child| process_node(child) }
    end

    def process_link_node(node)
      url = node['url']
      return unless url.present?

      # Skip if already migrated (already has prefix)
      if already_migrated?(url)
        @links_skipped += 1
        return
      end

      # Skip external links (http/https)
      if external_link?(url)
        @links_skipped += 1
        return
      end

      # Normalize the URL to get the slug
      slug = normalize_slug(url)
      return if slug.blank?

      # Check if it matches a brand
      if brand_slug?(slug)
        node['url'] = "#{BRAND_PREFIX}/#{slug}"
        @links_migrated += 1
        Rails.logger.info("[LexicalLinkMigrator] #{record_identifier} Updated brand link: #{url} -> #{node['url']}")
        return
      end

      # Check if it matches a blog/news
      if blog_slug?(slug)
        node['url'] = "#{NEWS_PREFIX}/#{slug}"
        @links_migrated += 1
        Rails.logger.info("[LexicalLinkMigrator] #{record_identifier} Updated news link: #{url} -> #{node['url']}")
        return
      end

      # If no match found, skip
      @links_skipped += 1
    end

    def load_slugs
      @brand_slugs = Brand.pluck(:slug).to_set
      @blog_slugs = Blog.pluck(:slug).to_set
    end

    def brand_slug?(slug)
      @brand_slugs.include?(slug)
    end

    def blog_slug?(slug)
      @blog_slugs.include?(slug)
    end

    def normalize_slug(url)
      # Remove leading slash if present
      slug = url.start_with?('/') ? url[1..-1] : url

      # Remove trailing slash if present
      slug = slug.end_with?('/') ? slug[0..-2] : slug

      # Remove query parameters and fragments
      slug = slug.split('?').first
      slug = slug.split('#').first

      # If there are multiple path segments, take the last one
      # e.g., '/some/path/nike' -> 'nike'
      slug = slug.split('/').last if slug.include?('/')

      slug
    end

    def already_migrated?(url)
      url.start_with?(BRAND_PREFIX) || url.start_with?(NEWS_PREFIX)
    end

    def external_link?(url)
      url.start_with?('http://') || url.start_with?('https://') || url.start_with?('//')
    end

    def record_identifier
      "#{@record.class.name}##{@record.id}"
    end

    def log_result
      return if @links_migrated.zero? && @links_skipped.zero?

      msg = "[LexicalLinkMigrator] #{record_identifier} - #{@links_migrated} migrated"
      msg += ", #{@links_skipped} skipped" if @links_skipped > 0
      Rails.logger.info(msg)
    end
  end
end
