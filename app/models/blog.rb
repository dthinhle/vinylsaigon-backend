
# == Schema Information
#
# Table name: blogs
#
#  id               :bigint           not null, primary key
#  content          :jsonb            not null
#  deleted_at       :datetime
#  meta_description :string(500)
#  meta_title       :string(255)
#  published_at     :datetime
#  slug             :string           not null
#  status           :string           default("draft"), not null
#  title            :string           not null
#  view_count       :integer          default(0)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  author_id        :bigint           not null
#  category_id      :bigint
#  source_wp_id     :bigint
#
# Indexes
#
#  index_blogs_on_author_id     (author_id)
#  index_blogs_on_category_id   (category_id)
#  index_blogs_on_deleted_at    (deleted_at)
#  index_blogs_on_slug          (slug) UNIQUE WHERE (deleted_at IS NULL)
#  index_blogs_on_source_wp_id  (source_wp_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (author_id => admins.id)
#  fk_rails_...  (category_id => blog_categories.id)
#
class Blog < ApplicationRecord
 include Sluggable

  has_paper_trail(
    versions: { class_name: 'PaperTrail::Version' },
    limit: 10,
  )

  enum :status, { draft: 'draft', published: 'published', archived: 'archived' }

  belongs_to :author, class_name: 'Admin'
  belongs_to :category, class_name: 'BlogCategory', optional: true, counter_cache: :blogs_count

  has_one_attached :image, dependent: :purge_later do |attachable|
    attachable.variant :thumbnail, resize_to_limit: [800, 800], preprocessed: true
  end

  has_many_attached :videos, dependent: :purge_later
  has_many_attached :content_images, dependent: :purge_later

  has_many :blog_products, dependent: :destroy
  has_many :products, through: :blog_products

  validates :title, presence: true
  validates :published_at, presence: true, if: :published?

  # Callbacks
  before_save :normalize_content
  after_update_commit :revalidate_frontend_cache
  after_destroy :revalidate_all_blogs
  after_commit :reindex, on: [:create, :update, :destroy]
  after_save :link_mentioned_products, if: :saved_change_to_content?
  after_save :process_external_content_images, if: :saved_change_to_content?

  # Generate short description from content for API responses
  def short_description(length = 200)
    return nil if content.blank?

    plain_text = if content.is_a?(Hash) && content['root']
      # Extract text from Lexical JSON structure
      extract_text_from_lexical(content['root'])
    else
      # Assume HTML string
      doc = Nokogiri::HTML(content)
      doc.css('script, style, iframe').remove
      doc.text.strip.gsub(/\s+/, ' ')
    end

    plain_text.length < length ? plain_text : plain_text.truncate(length, separator: ' ')
  end

  # Convert Lexical content to HTML
  def content_html
    return '' if content.blank?
    LexicalToHtmlConverter.convert(content, blog_title: title)
  end

  # Extract text content from Lexical for search and indexing
  def content_text
    return '' if content.blank?

    if content.is_a?(Hash) && content['root']
      extract_text_from_lexical(content['root'])
    else
      # If it's already HTML, extract text from it
      doc = Nokogiri::HTML(content.to_s)
      doc.text.strip.gsub(/\s+/, ' ')
    end
  end

  # Returns the next published blog post based on published_at date
  def next_post
    Blog.published
        .where('published_at > ?', published_at)
        .where.not(id: id)
        .order(published_at: :asc)
        .first
  end

  # Returns the previous published blog post based on published_at date
  def previous_post
    Blog.published
        .where('published_at < ?', published_at)
        .where.not(id: id)
        .order(published_at: :desc)
        .first
  end

  # Returns the first image URL found in the blog content
  def first_content_image_url
    return nil if content.blank?

    @first_content_image_url ||= begin
      if content.is_a?(Hash) && content['root']
        # Extract image from Lexical JSON structure
        extract_first_image_from_lexical(content['root'])
      else
        # Fallback to HTML parsing
        doc = Nokogiri::HTML(content.to_s)
        img = doc.at_css('img')
        img ? img['src'] : nil
      end
    end
  end

  def reindex
    BlogIndexJob.perform_later(self.id)
  end

  private

  # Ensure content is always stored as a Hash (JSON object), not a String
  # This prevents issues where content might be saved as stringified JSON
  def normalize_content
    # If content is a String, try to parse it as JSON
    if content.is_a?(String)
      # Handle empty or blank strings
      if content.strip.empty?
        self.content = {
          'root' => {
            'type' => 'root',
            'format' => '',
            'indent' => 0,
            'version' => 1,
            'children' => [],
            'direction' => nil
          }
        }
        Rails.logger.info "Blog ##{id || 'new'}: Set empty content to default Lexical structure"
      else
        # Try to parse non-empty string as JSON
        begin
          self.content = JSON.parse(content)
          Rails.logger.info "Blog ##{id || 'new'}: Parsed stringified JSON content"
        rescue JSON::ParserError => e
          Rails.logger.error "Blog ##{id || 'new'}: Failed to parse content JSON: #{e.message}"
          # Keep the string as-is if we can't parse it - better than losing data
        end
      end
    end
  end

  # Recursively extract text from Lexical JSON nodes
  def extract_text_from_lexical(node)
    return '' unless node.is_a?(Hash)
    text = ''
    # Text node
    if node['type'] == 'text' && node['text'].present?
      text += node['text'] + ' '
    end
    # Process children recursively
    if node['children'].is_a?(Array)
      node['children'].each do |child|
        text += extract_text_from_lexical(child)
      end
    end
    text
  end

  # Recursively extract the first image URL from Lexical JSON nodes
  def extract_first_image_from_lexical(node)
    return nil unless node.is_a?(Hash)

    # Check if this is an image node
    if node['type'] == 'image'
      # Try different possible sources for the image URL
      src = node['fields']&.dig('src') || node['src']
      return src if src.present?
    end

    # Process children recursively
    if node['children'].is_a?(Array)
      node['children'].each do |child|
        img_url = extract_first_image_from_lexical(child)
        return img_url if img_url.present?
      end
    end

    nil
  end

  def revalidate_frontend_cache
    FrontendRevalidateJob.perform_later('Blog', id)
  end

  def revalidate_all_blogs
    BlogRevalidationService.new.revalidate_all_blogs
  end

  def link_mentioned_products
    BlogProductLinkerService.new(self).link_products
  end

  def process_external_content_images
    ContentImageProcessorService.call(self)
  end
end
