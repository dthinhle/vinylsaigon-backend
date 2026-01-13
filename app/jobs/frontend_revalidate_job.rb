class FrontendRevalidateJob < ApplicationJob
  queue_as :default

  class UnsupportedModelError < StandardError; end

  ALLOWED_MODELS = ['Product', 'Blog', 'Global'].freeze

  attr_reader :record

  def perform(model_type, record_id = nil)
    raise UnsupportedModelError, "Unsupported model type: #{model_type}" unless ALLOWED_MODELS.include?(model_type)

    case model_type
    when 'RedirectionMapping'
      revalidate_redirections_cache
      return
    when 'Global'
      revalidate_global_cache
      return
    end

    @record = model_type.constantize.find_by(id: record_id)
    return if record.nil?
    return unless acquire_lock

    slug = record.slug
    case model_type
    when 'Product'
      revalidate_product_cache(slug)
    when 'Blog'
      revalidate_blog_cache(slug)
    end
  ensure
    unlock_file if record.present?
  end

  private

  def acquire_lock
    if File.exist?(lock_file_name) && !lock_expired?
      return false
    end
    File.write(lock_file_name, Time.now.to_s)
    true
  end

  def lock_expired?
    return true unless File.exist?(lock_file_name)

    File.mtime(lock_file_name) < 10.minutes.ago
  rescue StandardError
    true
  end

  def unlock_file
    File.delete(lock_file_name) if File.exist?(lock_file_name)
  end

  def lock_file_name
    @lock_file_name ||= Rails.root.join('tmp', "#{record.class.name.downcase}_#{record.id}_revalidation.lock")
  end

  def revalidate_product_cache(slug)
    ProductRevalidationService.revalidate_specific_product(slug)
  end

  def revalidate_blog_cache(slug)
    BlogRevalidationService.revalidate_blog(slug)
  end

  def revalidate_global_cache
    GlobalRevalidationService.revalidate_menu
  end

  def revalidate_redirections_cache
    GlobalRevalidationService.revalidate_redirections
  end
end
