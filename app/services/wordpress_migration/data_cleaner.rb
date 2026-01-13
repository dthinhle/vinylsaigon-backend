# frozen_string_literal: true

module WordpressMigration
  # Utility service for cleaning HTML content from WordPress
  class DataCleaner
    FORMAT_CONSTANTS = {
      NORMAL: 0,
      BOLD: 1,
      ITALIC: 2,
      ITALIC_BOLD: 3,
      UNDERLINE_BOLD: 9,
      UNDERLINE_ITALIC: 10,
      UNDERLINE_ITALIC_BOLD: 11
    }

    MEDIA_ELEMENTS = %w[img iframe video].freeze

    class << self
      def clean_html(html)
        return '' if html.blank?

        doc = Nokogiri::HTML.fragment(html)

        strip_unnecessary_attributes(doc)

        doc.css('p').each do |p|
          p.remove if p.text.strip.empty? && p.children.empty?
        end

        convert_to_nodes(doc)
      end

      def extract_image_urls(html)
        return [] if html.blank?

        doc = Nokogiri::HTML.fragment(html)
        doc.css('img').map { |img| img['src'] }.compact
      end

      def strip_unnecessary_attributes(doc)
        doc.css('img').each do |img|
          img.remove_attribute('width')
          img.remove_attribute('height')
        end
      end

      def convert_to_nodes(doc)
        child_nodes = doc.children
                        .flat_map { |child| _node_to_lexical(child) }
                        .select { |child| child && child[:type] != 'linebreak' }
        cleaned = strip_nodes(child_nodes)
        wrapped = wrap_text_nodes_in_paragraphs(cleaned)
        root_node(wrapped)
      end

      # Lexical requires that only element nodes (paragraph, heading, image, etc.)
      # can be direct children of root, not text nodes.
      # This method wraps any loose text nodes in paragraph nodes.
      def wrap_text_nodes_in_paragraphs(nodes)
        return [] unless nodes.is_a?(Array)

        result = []
        text_buffer = []

        nodes.each do |node|
          if node[:type] == 'text'
            # Collect text nodes
            text_buffer << node
          else
            # Before adding element node, flush any buffered text nodes
            if text_buffer.any?
              result << {
                "type": 'paragraph',
                "format": '',
                "indent": 0,
                "version": 1,
                "direction": nil,
                "children": text_buffer,
                "textStyle": '',
                "textFormat": 0
              }
              text_buffer = []
            end
            result << node
          end
        end

        # Flush any remaining text nodes
        if text_buffer.any?
          result << {
            "type": 'paragraph',
            "format": '',
            "indent": 0,
            "version": 1,
            "direction": nil,
            "children": text_buffer,
            "textStyle": '',
            "textFormat": 0
          }
        end

        result
      end

      def strip_nodes(nodes)
        return [] unless nodes.is_a?(Array)

        # Remove linebreak nodes at root level
        nodes = nodes.reject { |n| n && n[:type] == 'linebreak' }

        # Remove nodes whose only children are linebreaks
        nodes.reject do |n|
          children = n[:children]
          next false unless children.is_a?(Array) && children.any?

          children.all? { |c| c.nil? || (c[:type] == 'linebreak') }
        end
      end

      def _node_to_lexical(node)
        case node.name
        when 'comment', 'hr', 'picture', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th', 'col', 'colgroup', 'form', 'button', 'script', 'style'
          nil
        when 'a'
          link_tag(node)
        when 'p', 'div', 'article', 'section', 'blockquote', 'header', 'main', 'footer', 'dl', 'aside'
          handle_paragraph_with_lists(node)
        when 'text', 'dt', 'dd'
          raw_text_node(node)
        when 'strong', 'b', 'em', 'i', 'span', 'u', 'sup', 'sub', 'ins', 'del', 'mark', 'small'
          handle_text_node_with_media(node)
        when 'br'
          line_break_node
        when 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'
          handle_element_with_media(node, :heading)
        when 'ul', 'ol'
          children = node.children
            .flat_map { |child| _node_to_lexical(child) }
            .select { |child| child && child[:type] != 'linebreak' }

          if children.any? { |child| child[:type] != 'listitem' }
            foreign_nodes = []
            list_items = []
            children.each do |node|
              if node[:type] == 'listitem'
                list_items << node
              else
                foreign_nodes << node
              end
            end

            return [list_node(node, list_items), *foreign_nodes]
          end
          list_node(node, children)
        when 'li'
          children = node.children.flat_map { |child| _node_to_lexical(child) }.compact
          while children.first && children.first[:type] == 'linebreak'
            children.shift
          end
          while children.last && children.last[:type] == 'linebreak'
            children.pop
          end

          nested_lists = children.select { |child| child[:type] == 'list' }
          if nested_lists.any?
            non_list_children = children.reject { |child| child[:type] == 'list' }
            flattened_items = []

            flattened_items << list_item_node(non_list_children) if non_list_children.any?

            nested_lists.each do |nested_list|
              flattened_items.concat(nested_list[:children])
            end

            return flattened_items
          end

          list_item_node(children)
        when 'figure'
          node.children
              .to_a
              .filter { |child| child.name == 'img' }
              .flat_map { |child| _node_to_lexical(child) }.compact
        when 'img'
          image_node(node)
        when 'iframe'
          youtube_node(node)
        when 'video'
          video_node(node)
        else
          # Handle unknown elements gracefully
          # Most unknown elements (ins, del, mark, small, etc.) should be treated as inline text
          # Log for debugging but don't crash
          Rails.logger.debug("[DataCleaner] Unknown element: #{node.name}")

          # Process as inline text node if it has text content
          if node.text.present?
            text_node(node)
          else
            # If no text, try processing children
            node.children.flat_map { |child| _node_to_lexical(child) }.compact
          end
        end
      end

      def contains_media?(node)
        return true if MEDIA_ELEMENTS.include?(node.name)
        return false unless node.respond_to?(:children)

        node.children.any? { |child| contains_media?(child) }
      end

      def handle_element_with_media(node, element_type)
        children = node.children.flat_map { |child| _node_to_lexical(child) }.compact
        has_media = children.any? { |child| %w[image youtube video].include?(child[:type]) }

        unless has_media
          return element_type == :heading ? heading_node(node, children) : paragraph_node_from_children(children)
        end

        split_on_media(node, children, element_type)
      end

      def handle_text_node_with_media(node)
        children = text_node(node)
        return children unless children.is_a?(Array)

        has_media = children.any? { |child| %w[image youtube video].include?(child[:type]) }
        return children unless has_media

        split_text_on_media(children)
      end

      def split_text_on_media(children)
        result = []
        current_text_nodes = []

        children.each do |child|
          if %w[image youtube video].include?(child[:type])
            if current_text_nodes.any?
              result.concat(current_text_nodes)
              current_text_nodes = []
            end
            result << child
          else
            current_text_nodes << child
          end
        end

        result.concat(current_text_nodes) if current_text_nodes.any?
        result
      end

      def split_on_media(node, children, element_type)
        result = []
        current_children = []

        children.each do |child|
          if %w[image youtube video].include?(child[:type])
            if current_children.any?
              result << build_element_node(node, current_children, element_type)
              current_children = []
            end
            result << child
          else
            current_children << child
          end
        end

        if current_children.any?
          result << build_element_node(node, current_children, element_type)
        end

        result
      end

      def build_element_node(node, children, element_type)
        case element_type
        when :heading
          heading_node(node, children)
        when :paragraph
          paragraph_node_from_children(children)
        else
          paragraph_node_from_children(children)
        end
      end

      def paragraph_node_from_children(children)
        {
          "type": 'paragraph',
          "format": '',
          "indent": 0,
          "version": 1,
          "direction": nil,
          "children": children,
          "textStyle": '',
          "textFormat": 0
        }
      end

      def root_node(children = [])
        {
          "root": {
            "type": 'root',
            "format": '',
            "indent": 0,
            "version": 1,
            "children": children,
            "direction": nil
          }
        }
      end

      def link_tag(link_node)
        {
          "rel": link_node['rel'],
          "url": link_node['href'],
          "type": 'link',
          "title": nil,
          "format": '',
          "indent": 0,
          "target": nil,
          "version": 1,
          "children": [
            {
              "mode": 'normal',
              "text": link_node.text,
              "type": 'text',
              "style": '',
              "detail": 0,
              "format": 0,
              "version": 1
            },
          ],
          "direction": nil
        }
      end

      def paragraph_node(node)
        children = node.children.flat_map { |child| _node_to_lexical(child) }.compact

        {
          "type": 'paragraph',
          "format": '',
          "indent": 0,
          "version": 1,
          "direction": nil,
          "children": children,
          "textStyle": '',
          "textFormat": 0
        }
      end

      def handle_paragraph_with_lists(node)
        has_list = node.css('ul, ol').any?

        return paragraph_node(node) unless has_list

        result = []
        current_paragraph_children = []

        node.children.each do |child|
          if %w[ul ol].include?(child.name)
            if current_paragraph_children.any?
              result << {
                "type": 'paragraph',
                "format": '',
                "indent": 0,
                "version": 1,
                "direction": nil,
                "children": current_paragraph_children.flat_map { |c| _node_to_lexical(c) }.compact,
                "textStyle": '',
                "textFormat": 0
              }
              current_paragraph_children = []
            end

            list_nodes = _node_to_lexical(child)
            result << list_nodes if list_nodes
          else
            current_paragraph_children << child
          end
        end

        if current_paragraph_children.any?
          result << {
            "type": 'paragraph',
            "format": '',
            "indent": 0,
            "version": 1,
            "direction": nil,
            "children": current_paragraph_children.flat_map { |c| _node_to_lexical(c) }.compact,
            "textStyle": '',
            "textFormat": 0
          }
        end

        result.compact
      end

      def text_node(text_node, format: '', style: '')
        child_format = format
        child_style = style

        # Determine format based on parent element
        case text_node.name
        when 'strong', 'b'
          child_format = FORMAT_CONSTANTS[:BOLD]
        when 'em', 'i'
          child_format = FORMAT_CONSTANTS[:ITALIC]
        when 'u'
          child_format = FORMAT_CONSTANTS[:UNDERLINE]
        end

        text_node.children.flat_map do |child|
          # Process media elements (img, iframe, video) regardless of parent
          if %w[img iframe video].include?(child.name)
            next _node_to_lexical(child)
          end

          # Skip non-inline formatting tags (they should not be inside text_node)
          if %w[h1 h2 h3 h4 h5 h6 div p ul ol li table].include?(child.name)
            next _node_to_lexical(child)
          end

          # For inline formatting tags (span, strong, em, u), process their children recursively
          if %w[span strong b em i u].include?(child.name)
            next text_node(child, format: child_format, style: child_style)
          end

          # For text nodes, apply formatting and split on newlines
          if child.text?
            text = child.text
            if text == "\n"
              next line_break_node
            elsif text.strip.empty?
              next nil
            end
            next split_text_with_linebreaks(text, format: child_format, style: child_style)
          end

          nil
        end.compact
      end

      def raw_text_node(text_node)
        return nil if text_node.text.strip.empty?

        case text_node.name
        when 'strong', 'b'
          format = FORMAT_CONSTANTS[:BOLD]
        when 'em'
          format = FORMAT_CONSTANTS[:ITALIC]
        end

        # Split text on newlines and create text + linebreak nodes
        split_text_with_linebreaks(text_node.text, format: format)
      end

      def line_break_node
        {
          "type": 'linebreak',
          "version": 1
        }
      end

      def heading_node(node, children = [])
        {
          "tag": node.name,
          "type": 'heading',
          "version": 1,
          "format": '',
          "indent": 0,
          "children": children,
          "direction": nil
        }
      end

      def list_node(node, children = [])
        {
          "type": 'list',
          "tag": node.name,
          "start": 1,
          "version": 1,
          "format": '',
          "indent": 0,
          "children": children,
          "listType": node.name == 'ul' ? 'bullet' : 'number',
          "direction": nil
        }
      end

      def list_item_node(children = [])
        {
          "type": 'listitem',
          "version": 1,
          "start": 1,
          "format": '',
          "indent": 0,
          "children": children,
          "direction": nil
        }
      end

      def image_node(img_node)
        if img_node['height'].nil? && img_node['width'].nil?
          img_node['height'] = 'auto'
          img_node['width'] = '100%'
        end
        {
          "altText": img_node['alt'],
          "height": img_node['height'],
          "src": img_node['src'],
          "width": img_node['width'],
          "type": 'image',
          "version": 1
        }
      end

      def youtube_node(iframe_node)
        video_id = extract_youtube_id(iframe_node['src'])
        return nil unless video_id

        {
          "videoID": video_id,
          "type": 'youtube',
          "version": 1
        }
      end

      def video_node(video_node)
        {
          "src": video_node['src'],
          "type": 'video',
          "version": 1
        }
      end

      def extract_youtube_id(url)
        youtube_regex = /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?\&]v=)|youtu\.be\/)([^"\&?\/\s]{11})(?:[?\&]si=[^\&\s]*)?/
        match = url.match(youtube_regex)
        match ? match[1] : nil
      end

      # Split text on newlines and create an array of text and linebreak nodes
      # This preserves WordPress line breaks while normalizing other whitespace
      def split_text_with_linebreaks(text, format: nil, style: '')
        return [] if text.nil? || text.strip.empty?

        # First normalize \r\n to \n
        text = text.gsub(/\r\n/, "\n")

        # Split on \n to create separate text and linebreak nodes
        parts = text.split("\n", -1)  # -1 to keep empty strings
        nodes = []

        parts.each_with_index do |part, index|
          # Only collapse 2+ consecutive spaces (preserve single spaces and formatting)
          # This maintains intentional spacing while removing excessive whitespace
          normalized_part = part.gsub(/\s{2,}/, ' ')

          # Add text node if not empty
          if normalized_part.present?
            nodes << {
              "text": normalized_part,
              "type": 'text',
              "format": format,
              "style": style,
              "direction": nil,
              "textStyle": '',
              "detail": 0
            }
          end

          # Add linebreak node after each part except the last
          if index < parts.length - 1
            nodes << line_break_node
          end
        end

        nodes
      end
    end
  end
end
