# frozen_string_literal: true

class BlogImageMigrationJob < ApplicationJob
  queue_as :background
  sidekiq_options retry: 3, dead: true

  def perform(blog_id, options = {})
    blog = Blog.find(blog_id)

    Rails.logger.info("BlogImageMigrationJob: Starting image migration for blog #{blog_id} (#{blog.slug})")

    wp_db = WordpressDatabaseService.new

    begin
      wp_db.connect

      # Attach featured image
      attach_featured_image(blog, wp_db, force: options[:force_featured_image])

      # Process lexical content images
      migrate_lexical_content_images(blog) unless options[:only_featured_image]

      Rails.logger.info("BlogImageMigrationJob: Completed for blog #{blog_id}")
    rescue => e
      Rails.logger.error("BlogImageMigrationJob: Error for blog #{blog_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    ensure
      wp_db.close
    end
  end

  private

  DEAD_IMAGE_DOMAINS = [
    'monospace.vn',
    'vinylsaigon.vn/Data/Sites',
  ].freeze

  FALLBACK_LOGO_URL = '/assets/logo.svg'

  def attach_featured_image(blog, wp_db, force: false)
    return if blog.image.attached? && !force

    postmeta = wp_db.query_all(
      "SELECT * FROM #{wp_db.table('postmeta')} WHERE post_id = #{blog.source_wp_id}"
    )

    thumbnail_meta = postmeta.find { |m| m['meta_key'] == '_thumbnail_id' }
    return unless thumbnail_meta

    thumbnail_id = thumbnail_meta['meta_value'].to_i
    attachment = wp_db.query_first(
      "SELECT guid FROM #{wp_db.table('posts')} WHERE ID = #{thumbnail_id}"
    )
    return unless attachment

    image_url = attachment['guid']
    return if image_url.blank?

    if dead_image_domain?(image_url)
      attach_fallback_logo(blog)
      return
    end

    result = ImageUploadService.call(url: image_url)

    if result[:success]
      blog.image.attach(result[:blob])
      Rails.logger.info("BlogImageMigrationJob: Featured image migrated for blog #{blog.id}")
    else
      Rails.logger.warn("BlogImageMigrationJob: Failed to attach featured image for blog #{blog.id}: #{result[:error]}")
    end
  rescue => e
    Rails.logger.error("BlogImageMigrationJob: Error attaching featured image for blog #{blog.id}: #{e.message}")
  end

  def migrate_lexical_content_images(blog)
    result = WordpressMigration::LexicalMediaMigratorService.call(record: blog, content_field: :content)

    if result[:success]
      Rails.logger.info("BlogImageMigrationJob: Blog #{blog.id} - Lexical images: #{result[:migrated]} migrated, #{result[:skipped]} skipped")
    else
      Rails.logger.error("BlogImageMigrationJob: Blog #{blog.id} - Lexical migration failed: #{result[:error]}")
    end
  end

  def dead_image_domain?(url)
    DEAD_IMAGE_DOMAINS.any? { |domain| url.include?(domain) }
  end

  def attach_fallback_logo(blog)
    return if blog.image.attached?

    backend_host = ENV.fetch('BACKEND_HOST', 'http://localhost:3001')
    fallback_url = "#{backend_host}#{FALLBACK_LOGO_URL}"

    result = ImageUploadService.call(url: fallback_url)

    if result[:success]
      blog.image.attach(result[:blob])
      Rails.logger.info("BlogImageMigrationJob: Fallback logo attached for blog #{blog.id}")
    else
      Rails.logger.warn("BlogImageMigrationJob: Failed to attach fallback logo for blog #{blog.id}: #{result[:error]}")
    end
  rescue => e
    Rails.logger.error("BlogImageMigrationJob: Error attaching fallback logo for blog #{blog.id}: #{e.message}")
  end
end
