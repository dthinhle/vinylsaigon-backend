# frozen_string_literal: true

module WordpressMigration
  class LexicalMediaMigratorService
    include Rails.application.routes.url_helpers

    DEAD_IMAGE_DOMAINS = %w[
      monospace.vn
      vinylsaigon.vn/Data/Sites
    ].freeze

    FALLBACK_LOGO_PATH = '/assets/logo.svg'

    class << self
      def call(record:, content_field: :content)
        new(record: record, content_field: content_field).call
      end
    end

    def initialize(record:, content_field:)
      @record = record
      @content_field = content_field
      @images_migrated = 0
      @images_skipped = 0
      @blobs_attached = []
      @content_modified = false
    end

    def call
      content = @record.public_send(@content_field)
      return { success: true, migrated: 0, skipped: 0 } if content.blank? || !content.is_a?(Hash)

      root = content['root']
      return { success: true, migrated: 0, skipped: 0 } unless root

      process_node(root)

      if @images_migrated > 0 || @content_modified
        @record.update_column(@content_field, content)
        attach_blobs_to_record
      end

      log_result

      { success: true, migrated: @images_migrated, skipped: @images_skipped, blobs: @blobs_attached }
    rescue StandardError => e
      Rails.logger.error("[LexicalMediaMigrator] #{record_identifier} Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      { success: false, error: e.message }
    end

    private

    def process_node(node)
      return unless node.is_a?(Hash)

      result = nil
      case node['type']
      when 'image'
        result = process_image_node(node)
      when 'video'
        process_video_node(node)
      end

      return :delete_node if result == :delete_node

      process_children(node)
      process_caption(node)
    end

    def process_children(node)
      return unless node['children'].is_a?(Array)

      node['children'].reject! do |child|
        if process_node(child) == :delete_node
          @content_modified = true
          true
        else
          false
        end
      end
    end

    def process_caption(node)
      return unless node['caption'].is_a?(Hash) && node['caption']['editorState'].is_a?(Hash)

      process_node(node['caption']['editorState'])
    end

    def process_image_node(node)
      src = node['src']
      return unless src.present?

      src = normalize_url(src)

      if already_migrated?(src)
        @images_skipped += 1
        return
      end

      if dead_image_domain?(src)
        Rails.logger.info("[LexicalMediaMigrator] #{record_identifier} Removed dead image: #{src}")
        return :delete_node
      end

      migrate_image(node, src)
    end

    def process_video_node(node)
      src = node['src']
      return unless src.present?

      src = normalize_url(src)

      return if already_migrated?(src)

      # Video URL download not yet supported - would need VideoDownloadService
      Rails.logger.debug("[LexicalMediaMigrator] #{record_identifier} Skipping video (URL download not supported): #{src}")
    end

    def migrate_image(node, src)
      result = ImageUploadService.call(url: src)

      unless result[:success]
        Rails.logger.warn("[LexicalMediaMigrator] #{record_identifier} Failed to download: #{src} - #{result[:error]}")
        return :delete_node
      end

      blob = result[:blob]
      new_url = rails_blob_url(blob, host: default_url_options[:host], protocol: default_url_options[:protocol] || 'http')
      node['src'] = new_url
      @blobs_attached << blob
      @images_migrated += 1

      cache_status = result[:cache_hit] ? 'cached' : 'downloaded'
      Rails.logger.info("[LexicalMediaMigrator] #{record_identifier} Migrated (#{cache_status}): #{src}")
    rescue StandardError => e
      Rails.logger.error("[LexicalMediaMigrator] #{record_identifier} Error migrating #{src}: #{e.message}")
    end

    def attach_blobs_to_record
      return if @blobs_attached.empty?
      return unless @record.respond_to?(:content_images)

      @record.reload

      @blobs_attached.each do |blob|
        next if @record.content_images.blobs.exists?(id: blob.id)

        ActiveStorage::Attachment.create!(
          name: 'content_images',
          record: @record,
          blob: blob
        )
      end
    end

    def already_attached?(blob)
      @record.content_images.blobs.exists?(id: blob.id)
    end

    def normalize_url(url)
      url = url.gsub('//', 'https://') if url.start_with?('//')

      if url.start_with?('/')
        wp_source_url = ENV.fetch('WP_SOURCE_URL', 'https://vinylsaigon.vn')
        url = "#{wp_source_url}#{url}"
      end

      url
    end

    def already_migrated?(url)
      url.include?('/rails/active_storage/')
    end

    def dead_image_domain?(url)
      DEAD_IMAGE_DOMAINS.any? { |domain| url.include?(domain) }
    end

    def fallback_logo_url
      backend_host = ENV.fetch('BACKEND_HOST', 'http://localhost:3001')
      "#{backend_host}#{FALLBACK_LOGO_PATH}"
    end

    def default_url_options
      Rails.application.config.action_mailer.default_url_options
    end

    def record_identifier
      "#{@record.class.name}##{@record.id}"
    end

    def log_result
      return if @images_migrated.zero? && @images_skipped.zero?

      msg = "[LexicalMediaMigrator] #{record_identifier} - #{@images_migrated} migrated"
      msg += ", #{@images_skipped} skipped" if @images_skipped > 0
      Rails.logger.info(msg)
    end
  end
end
