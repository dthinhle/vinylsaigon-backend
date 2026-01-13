# frozen_string_literal: true

# Background job for WordPress data migration
class WordpressMigrationJob < ApplicationJob
  queue_as :default

  def perform(categories_json: nil, products_json: nil, options: {})
    result = {
      categories: { success: false, errors: [], migrated_count: 0 },
      products: { success: false, errors: [], warnings: [], migrated_count: 0 },
      started_at: Time.current,
      completed_at: nil
    }

    @page = options[:page]
    skip_categories = options[:skip_categories] || false
    use_api = categories_json.blank? && products_json.blank?

    begin
      if skip_categories
        Rails.logger.info('Skipping category migration (skip_categories option enabled)')
        result[:categories] = { success: true, errors: [], migrated_count: 0 }
        category_mapping = {}
      elsif use_api
        category_result = migrate_categories_from_api
        result[:categories] = category_result
        category_mapping = category_result[:mapping] || {}
      elsif categories_json.present?
        category_result = migrate_categories(categories_json)
        result[:categories] = category_result
        category_mapping = category_result[:mapping] || {}
      else
        category_mapping = {}
      end

      if use_api
        product_result = migrate_products_from_api(category_mapping, options)
        result[:products] = product_result
      elsif products_json.present?
        product_result = migrate_products(products_json, category_mapping)
        result[:products] = product_result
      end

      result[:completed_at] = Time.current
      result[:success] = result[:categories][:success] && result[:products][:success]

      Rails.logger.info("WordPress Migration completed: #{result[:success] ? 'SUCCESS' : 'FAILED'}")
      Rails.logger.info("Categories migrated: #{result[:categories][:migrated_count]}")
      Rails.logger.info("Products migrated: #{result[:products][:migrated_count]}")

      result
    rescue StandardError => e
      Rails.logger.error("WordPress Migration Job failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      result[:completed_at] = Time.current
      result[:success] = false
      result[:error] = e.message
      result
    end
  end

  private

  def migrate_categories(categories_json)
    migrator = WordpressMigration::CategoryMigrator.new(categories_json)
    result = migrator.migrate!

    {
      success: result[:success],
      errors: result[:errors],
      migrated_count: result[:mapping].size,
      mapping: result[:mapping]
    }
  end

  def migrate_products(products_json, category_mapping)
    migrator = WordpressMigration::ProductMigrator.new(products_json, category_mapping)
    result = migrator.migrate!

    {
      success: result[:success],
      errors: result[:errors],
      warnings: result[:warnings],
      migrated_count: result[:migrated_count],
      migrated_products: result[:migrated_products]
    }
  end

  def migrate_categories_from_api
    cache_responses = Rails.env.local?
    fetcher = WordpressMigration::CategoryFetcher.new(nil, cache_responses: cache_responses)
    categories = fetcher.fetch_all
    migrate_categories(categories)
  rescue WordpressMigration::ApiClient::ApiError => e
    {
      success: false,
      errors: [e.message],
      migrated_count: 0,
      mapping: {}
    }
  end

  def migrate_products_from_api(category_mapping, options)
    cache_responses = Rails.env.local?
    fetcher = WordpressMigration::ProductFetcher.new(nil, cache_responses: cache_responses)
    if @page.present?
      per_page = options[:per_page] || 50
      products = fetcher.fetch_batch(page: @page, per_page: per_page)
    else
      per_page = options[:per_page] || 50
      products = fetcher.fetch_all(per_page: per_page)
    end
    migrate_products(products[:products], category_mapping)
  rescue WordpressMigration::ApiClient::ApiError => e
    {
      success: false,
      errors: [e.message],
      warnings: [],
      migrated_count: 0,
      migrated_products: []
    }
  end
end
