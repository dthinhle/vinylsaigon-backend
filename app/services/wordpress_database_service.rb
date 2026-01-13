# frozen_string_literal: true

# Service to connect to and query WordPress MySQL database
# Supports migration of blogs, categories, products, and other WordPress data
class WordpressDatabaseService
  attr_reader :client, :prefix

  def initialize
    @config = {
      host: ENV.fetch('WP_DB_HOST', '127.0.0.1'),
      port: ENV.fetch('WP_DB_PORT', 3306).to_i,
      username: ENV.fetch('WP_DB_USERNAME', 'root'),
      password: ENV.fetch('WP_DB_PASSWORD', 'root'),
      database: ENV.fetch('WP_DB_NAME', 'my_3k_blog'),
      encoding: 'utf8mb4'
    }
    @prefix = ENV.fetch('WP_TABLE_PREFIX', '2uhNN_')
    @client = nil
  end

  # Connect to WordPress database
  def connect
    require 'mysql2'
    @client = Mysql2::Client.new(@config)
    Rails.logger.info("Connected to WordPress database: #{@config[:database]}@#{@config[:host]}")
    @client
  rescue Mysql2::Error => e
    Rails.logger.error("WordPress DB connection error: #{e.message}")
    raise
  end

  # Close database connection
  def close
    @client&.close
    @client = nil
  end

  # Execute a query and return results
  def query(sql, **options)
    ensure_connected
    @client.query(sql, **options)
  rescue Mysql2::Error => e
    Rails.logger.error("WordPress DB query error: #{e.message}")
    Rails.logger.error("SQL: #{sql}")
    raise
  end

  # Execute a query and return first result
  def query_first(sql, **options)
    query(sql, **options).first
  end

  # Execute a query and return all results as array
  def query_all(sql, **options)
    query(sql, **options).to_a
  end

  # Get table name with prefix
  def table(name)
    "#{@prefix}#{name}"
  end

  # === WordPress-specific query helpers ===

  # Get all categories from WordPress
  def get_categories
    sql = <<-SQL
      SELECT t.term_id, t.name, t.slug
      FROM #{table('terms')} t
      INNER JOIN #{table('term_taxonomy')} tt ON t.term_id = tt.term_id
      WHERE tt.taxonomy = 'category'
      ORDER BY t.term_id
    SQL
    query_all(sql)
  end

  # Get all posts (with optional filters)
  # @param post_type [String] WordPress post type (default: 'post')
  # @param statuses [Array<String>] Post statuses to include
  # @param limit [Integer] Maximum number of posts to fetch
  # @param date_from [String, Date, Time] Filter posts published after this date
  def get_posts(post_type: 'post', statuses: ['publish', 'draft', 'pending'], limit: nil, date_from: nil)
    status_list = statuses.map { |s| "'#{s}'" }.join(', ')
    date_filter = date_from ? "AND p.post_date >= '#{date_from}'" : ''
    sql = <<-SQL
      SELECT
        p.ID,
        p.post_author,
        p.post_date,
        p.post_content,
        p.post_title,
        p.post_excerpt,
        p.post_status,
        p.post_name,
        p.post_modified,
        p.guid
      FROM #{table('posts')} p
      WHERE p.post_type = '#{post_type}'
      AND p.post_status IN (#{status_list})
      #{date_filter}
      ORDER BY p.ID
      #{limit ? "LIMIT #{limit}" : ''}
    SQL
    query_all(sql)
  end

  # Get post metadata for multiple posts
  # @param meta_keys [Array<String>] Meta keys to fetch (optional, fetches all if not specified)
  def get_postmeta(meta_keys: nil)
    where_clause = meta_keys ? "WHERE meta_key IN (#{meta_keys.map { |k| "'#{k}'" }.join(', ')})" : ''
    sql = <<-SQL
      SELECT post_id, meta_key, meta_value
      FROM #{table('postmeta')}
      #{where_clause}
    SQL
    query_all(sql)
  end

  # Get all post-category relationships
  def get_term_relationships
    sql = <<-SQL
      SELECT object_id, term_taxonomy_id
      FROM #{table('term_relationships')}
    SQL
    query_all(sql)
  end

  # Get term taxonomy mappings
  # @param taxonomy [String] Taxonomy type (e.g., 'category', 'post_tag')
  def get_term_taxonomy(taxonomy: 'category')
    sql = <<-SQL
      SELECT term_taxonomy_id, term_id
      FROM #{table('term_taxonomy')}
      WHERE taxonomy = '#{taxonomy}'
    SQL
    query_all(sql)
  end

  # Get all users
  def get_users
    sql = <<-SQL
      SELECT ID, user_email, user_login, display_name
      FROM #{table('users')}
    SQL
    query_all(sql)
  end

  # Get attachment by ID
  # @param attachment_id [Integer] WordPress attachment post ID
  def get_attachment(attachment_id)
    sql = <<-SQL
      SELECT guid
      FROM #{table('posts')}
      WHERE ID = #{attachment_id}
      LIMIT 1
    SQL
    query_first(sql)
  end

  # Get products (WooCommerce)
  def get_products(statuses: ['publish'], limit: nil)
    get_posts(post_type: 'product', statuses: statuses, limit: limit)
  end

  # Get product categories (WooCommerce)
  def get_product_categories
    sql = <<-SQL
      SELECT t.term_id, t.name, t.slug
      FROM #{table('terms')} t
      INNER JOIN #{table('term_taxonomy')} tt ON t.term_id = tt.term_id
      WHERE tt.taxonomy = 'product_cat'
      ORDER BY t.term_id
    SQL
    query_all(sql)
  end

  # Execute a block with automatic connection management
  def with_connection
    connect unless @client
    yield self
  ensure
    close if @client
  end

  private

  def ensure_connected
    connect unless @client
  end
end
