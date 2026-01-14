# frozen_string_literal: true

module WordpressMigration
  require_relative 'yoast_seo_variable_replacer'
  class BlogMigratorService
    include Rails.application.routes.url_helpers

    attr_reader :wp_db_service, :stats

    def initialize(wp_db_service)
      @wp_db_service = wp_db_service
      @stats = {
        categories: 0,
        posts_inserted: 0,
        posts_updated: 0,
        posts_skipped: 0
      }
    end

    def migrate_all
      migrate_categories
      migrate_posts
      @stats
    end

    def migrate_categories
      puts '--- Migrating Categories ---'
      wp_categories = @wp_db_service.get_categories
      category_map = {}

      wp_categories.each do |wp_cat|
        category = BlogCategory.find_or_initialize_by(source_wp_id: wp_cat['term_id'])
        category.name = wp_cat['name']
        category.slug = wp_cat['slug']

        if category.save
          category_map[wp_cat['term_id']] = category
          puts "✓ Saved Category: #{category.name} (#{category.slug})"
        else
          puts "✗ Error saving category #{wp_cat['name']}: #{category.errors.full_messages.join(', ')}"
        end
      end

      @stats[:categories] = category_map.size
      @category_map = category_map
      puts
    end

    def migrate_posts
      puts '--- Migrating Posts ---'

      # Only migrate posts from last 3 years
      years_limit = ENV.fetch('WORDPRESS_MIGRATION_POST_YEARS_LIMIT', '30').to_i
      three_years_ago = years_limit.years.ago
      puts "Filtering posts from #{three_years_ago.strftime('%Y-%m-%d')} onwards (last 3 years)"
      puts

      wp_posts = @wp_db_service.get_posts(
        post_type: 'post',
        statuses: ['publish', 'draft', 'pending'],
        date_from: three_years_ago
      )

      # Fetch supporting data
      postmeta_by_post = fetch_postmeta
      relationships_by_post, term_taxonomy_map = fetch_term_data
      user_map, default_admin = fetch_users

      # Process each post
      wp_posts.each do |wp_post|
        migrate_single_post(
          wp_post,
          postmeta_by_post,
          relationships_by_post,
          term_taxonomy_map,
          user_map,
          default_admin
        )
      end

      puts "\n"
    end

    private

    def fetch_postmeta
      all_postmeta = @wp_db_service.get_postmeta(
        meta_keys: ['_yoast_wpseo_title', '_yoast_wpseo_metadesc', '_thumbnail_id']
      )
      all_postmeta.group_by { |pm| pm['post_id'] }
    end

    def fetch_term_data
      term_relationships = @wp_db_service.get_term_relationships
      relationships_by_post = term_relationships.group_by { |tr| tr['object_id'] }

      term_taxonomy_map = {}
      @wp_db_service.get_term_taxonomy(taxonomy: 'category').each do |tt|
        term_taxonomy_map[tt['term_taxonomy_id']] = tt['term_id']
      end

      [relationships_by_post, term_taxonomy_map]
    end

    def fetch_users
      wp_users = @wp_db_service.get_users
      user_map = {}
      wp_users.each do |u|
        user_map[u['ID']] = {
          email: u['user_email'],
          name: u['display_name'].presence || u['user_login']
        }
      end

      temp_password = SecureRandom.alphanumeric(16)
      default_admin = Admin.first || Admin.create!(
        email: 'admin@vinylsaigon.vn',
        name: 'Admin',
        password: temp_password,
        password_confirmation: temp_password
      )

      [user_map, default_admin]
    end

    def migrate_single_post(wp_post, postmeta_by_post, relationships_by_post, term_taxonomy_map, user_map, default_admin)
      # Skip posts without title or slug
      if wp_post['post_title'].blank? || wp_post['post_name'].blank?
        puts "⚠ Skipping post ID #{wp_post['ID']} - blank title or slug"
        @stats[:posts_skipped] += 1
        return
      end

      blog = Blog.find_or_initialize_by(source_wp_id: wp_post['ID'])
      is_new_record = blog.new_record?

      # Assign author
      assign_author(blog, wp_post, user_map, default_admin)

      # Basic fields
      blog.title = CGI.unescapeHTML(wp_post['post_title']).strip
      blog.slug = wp_post['post_name']

      # Convert WordPress HTML to Lexical JSON using DataCleaner
      cleaned_content = preprocess_captions(wp_post['post_content'])
      cleaned_content = preprocess_shortcodes(cleaned_content)
      blog.content = WordpressMigration::DataCleaner.clean_html(
        cleaned_content,
        migrate_images: false  # Images handled separately in process_lexical_images
      )

      blog.status = wp_post['post_status'] == 'publish' ? 'published' : 'draft'
      blog.published_at = wp_post['post_date']

      # SEO metadata
      assign_seo_metadata(blog, postmeta_by_post[wp_post['ID']])

      # Category
      assign_category(blog, relationships_by_post[wp_post['ID']], term_taxonomy_map)

      # Save blog without image processing
      if blog.save
        # Enqueue background job for image migration
        BlogImageMigrationJob.perform_later(blog.id)

        if is_new_record
          @stats[:posts_inserted] += 1
        else
          @stats[:posts_updated] += 1
        end
        print '.'
      else
        puts "\n✗ Error saving post #{wp_post['ID']} (#{blog.title}): #{blog.errors.full_messages.join(', ')}"
        @stats[:posts_skipped] += 1
      end
    end

    def assign_author(blog, wp_post, user_map, default_admin)
      wp_author_data = user_map[wp_post['post_author']]
      author_id = nil

      if wp_author_data
        author = Admin.find_by(email: wp_author_data[:email])

        unless author
          puts "    [Blog #{wp_post['ID']}] Creating new author: #{wp_author_data[:name]} (#{wp_author_data[:email]})"
          author = Admin.create!(
            email: wp_author_data[:email],
            name: wp_author_data[:name],
            password: 'password123',
            password_confirmation: 'password123'
          )
        end

        author_id = author.id
      else
        author_id = default_admin.id
      end

      # Use author_id to avoid Rails class reloading issues in development
      blog.author_id = author_id
    end

    def assign_seo_metadata(blog, postmeta)
      return unless postmeta

      # Build context for Yoast variable replacement
      context = {
        title: blog.title,
        excerpt: generate_excerpt(blog.content),
        category: blog.category&.name || '',
        page: nil # Default to nil (no page number)
      }


      # Process meta title
      if meta_title = postmeta.find { |m| m['meta_key'] == '_yoast_wpseo_title' }
        raw_title = CGI.unescapeHTML(meta_title['meta_value']).strip
        if raw_title.present?
          # Replace Yoast variables if present
          if YoastSeoVariableReplacer.contains_variables?(raw_title)
            blog.meta_title = YoastSeoVariableReplacer.replace(raw_title, context)
            puts "    [Blog #{blog.source_wp_id}] Replaced Yoast variables in meta_title: #{raw_title} → #{blog.meta_title}"
          else
            blog.meta_title = raw_title
          end
        end
      end

      # Process meta description
      if meta_desc = postmeta.find { |m| m['meta_key'] == '_yoast_wpseo_metadesc' }
        raw_desc = CGI.unescapeHTML(meta_desc['meta_value']).strip
        if raw_desc.present?
          # Replace Yoast variables if present
          if YoastSeoVariableReplacer.contains_variables?(raw_desc)
            blog.meta_description = YoastSeoVariableReplacer.replace(raw_desc, context)
            puts "    [Blog #{blog.source_wp_id}] Replaced Yoast variables in meta_description: #{raw_desc} → #{blog.meta_description}"
          else
            blog.meta_description = raw_desc
          end
        end
      end
    end

    # Generate excerpt from Lexical content
    def generate_excerpt(content, max_length = 160)
      return '' unless content.is_a?(Hash) && content['root']

      text = extract_text_from_lexical(content['root'])
      text.truncate(max_length, separator: ' ', omission: '...')
    end

    # Recursively extract text from Lexical JSON
    def extract_text_from_lexical(node)
      return '' unless node.is_a?(Hash)

      text = ''

      # Extract text from text nodes
      if node['type'] == 'text' && node['text'].present?
        text += node['text'] + ' '
      end

      # Recursively process children
      if node['children'].is_a?(Array)
        node['children'].each do |child|
          text += extract_text_from_lexical(child)
        end
      end

      text
    end


    def assign_category(blog, relationships, term_taxonomy_map)
      # Default to nil (no category)
      blog.category_id = nil

      return unless relationships

      relationships.each do |rel|
        if wp_term_id = term_taxonomy_map[rel['term_taxonomy_id']]
          if category = @category_map[wp_term_id]
            blog.category_id = category.id
            break
          end
        end
      end
    end

    def preprocess_captions(html)
      return '' if html.blank?
      # Remove any [caption ...]...[/caption] blocks (including attributes)
      html.gsub(/\[caption[^\]]*\].*?\[\/caption\]/m, '')
    end

    def preprocess_shortcodes(html)
      return '' if html.blank?

      # Transform [su_button] shortcodes into HTML anchor tags
      html = html.gsub(/\[su_button\s+([^\]]*)\](.*?)\[\/su_button\]/mi) do
        attrs_str = Regexp.last_match(1)
        inner_text = Regexp.last_match(2)
        attrs = {}
        attrs_str.scan(/(\w+)="([^"]*)"/) { |k, v| attrs[k] = v }
        url = attrs['url'] || '#'
        target = attrs['target'] == 'self' ? '_self' : '_blank'
        style_parts = []
        style_parts << "background:#{attrs['background']}" if attrs['background']
        style_parts << "color:#{attrs['color']}" if attrs['color']
        style_parts << "border-radius:#{attrs['radius']}px" if attrs['radius']
        style_parts << "font-size:#{attrs['size']}px" if attrs['size']
        style = style_parts.join(';')
        class_attr = attrs['class']
        class_html = class_attr ? " class=\"#{class_attr}\"" : ''
        style_html = style.empty? ? '' : " style=\"#{style}\""
        "<a href=\"#{url}\" target=\"#{target}\"#{class_html}#{style_html}>#{inner_text}</a>"
      end

        # Transform [embed] shortcodes (e.g., YouTube, Vimeo) into iframes for known video domains
        html = html.gsub(/\[embed\](.*?)\[\/embed\]/mi) do
          url = Regexp.last_match(1).strip
          video_iframe = nil
          # YouTube (any query order)
          if url =~ /youtube\.com\/watch.*[?&]v=([\w-]+)/i || url =~ /youtu\.be\/([\w-]+)/i
            video_id = Regexp.last_match(1)
            video_iframe = "<iframe width=\"100%\" height=\"315\" src=\"https://www.youtube.com/embed/#{video_id}\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture\" allowfullscreen></iframe>"
          # Vimeo
          elsif url =~ /vimeo\.com\/.*?(\d+)/i
            video_id = Regexp.last_match(1)
            video_iframe = "<iframe width=\"100%\" height=\"315\" src=\"https://player.vimeo.com/video/#{video_id}\" frameborder=\"0\" allow=\"autoplay; fullscreen; picture-in-picture\" allowfullscreen></iframe>"
          end
          video_iframe || "<a href=\"#{url}\" target=\"_blank\">#{url}</a>"
        end

      # Convert plain YouTube URLs to iframes
      html = html.gsub(%r{https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)([\w-]+)}) do
        video_id = Regexp.last_match(1)
        "<iframe width=\"100%\" height=\"315\" src=\"https://www.youtube.com/embed/#{video_id}\" frameborder=\"0\" allow=\"accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture\" allowfullscreen></iframe>"
      end
      # Convert plain Vimeo URLs to iframes
      html = html.gsub(%r{https?://(?:www\.)?vimeo\.com/(\d+)}) do
        video_id = Regexp.last_match(1)
        "<iframe width=\"100%\" height=\"315\" src=\"https://player.vimeo.com/video/#{video_id}\" frameborder=\"0\" allow=\"autoplay; fullscreen; picture-in-picture\" allowfullscreen></iframe>"
      end
      # Remove any remaining unknown shortcodes
      html.gsub(/\[[a-zA-Z0-9_]+(?:\s[^\]]*)?\/?\]/, '')
    end

    def default_url_options
      Rails.application.config.action_mailer.default_url_options
    end
  end
end
