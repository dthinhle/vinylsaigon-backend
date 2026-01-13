# frozen_string_literal: true

require 'cgi'

# Converts Lexical editor JSON format to HTML
class LexicalToHtmlConverter
  def self.convert(lexical_json, blog_title: nil)
    new.convert(lexical_json, blog_title: blog_title)
  end

  def convert(lexical_json, blog_title: nil)
    @blog_title = blog_title
    return '' if lexical_json.blank?

    if lexical_json.is_a?(String)
      begin
        lexical_json = JSON.parse(lexical_json)
      rescue JSON::ParserError
        return ''
      end
    end

    return '' unless lexical_json.is_a?(Hash) && lexical_json['root']

    process_node(lexical_json['root'])
  end

 private

  def process_node(node)
    return '' unless node.is_a?(Hash)

    case node['type']
    when 'text'
      process_text_node(node)
    when 'paragraph'
      process_paragraph_node(node)
    when 'heading'
      process_heading_node(node)
    when 'list'
      process_list_node(node)
    when 'listitem'
      process_list_item_node(node)
    when 'quote'
      process_quote_node(node)
    when 'code'
      process_code_node(node)
    when 'horizontalrule'
      process_horizontal_rule_node(node)
    when 'link'
      process_link_node(node)
    when 'image'
      process_image_node(node)
    when 'table', 'tablecell', 'tablerow'
      process_table_node(node)
    else
      process_default_node(node)
    end
  end

  def process_text_node(node)
    text = node['text'] || ''
    format = node['format']

    format_str = case format
    when String
                   format
    when Integer
                   format_to_string(format)
    when NilClass
                   ''
    else
                   format.to_s
    end

    # Apply formatting based on format string
    text = "<strong class=\"font-semibold text-gray-900\">#{CGI.escape_html(text)}</strong>" if format_str.include?('bold')
    text = "<em class=\"italic text-gray-800\">#{CGI.escape_html(text)}</em>" if format_str.include?('italic')
    text = "<u class=\"underline\">#{CGI.escape_html(text)}</u>" if format_str.include?('underline')
    text = "<s class=\"line-through text-gray-500\">#{CGI.escape_html(text)}</s>" if format_str.include?('strikethrough')
    text = "<code class=\"bg-gray-100 px-2 py-0.5 rounded text-sm font-mono text-gray-800\">#{CGI.escape_html(text)}</code>" if format_str.include?('code')
    text = CGI.escape_html(text) if format_str.blank?
    text
  end

  # Convert integer format values to string representation
  # In Lexical editor, formatting can be stored as bitmask integers
  def format_to_string(format_int)
    format_flags = []
    format_flags << 'bold' if (format_int & 1).positive?
    format_flags << 'italic' if (format_int & 2).positive?
    format_flags << 'underline' if (format_int & 4).positive?
    format_flags << 'strikethrough' if (format_int & 8).positive?
    format_flags << 'code' if (format_int & 16).positive?
    format_flags.join(' ')
  end

  def process_paragraph_node(node)
    children_html = process_children(node)
    "<p class=\"my-4 text-gray-700 leading-relaxed\">#{children_html}</p>"
  end

  def process_heading_node(node)
    level = node['tag']&.match(/h(\d)/) ? node['tag'][1] : node['level'] || 1
    level = level.to_i.clamp(1, 6)
    children_html = process_children(node)
    classes = case level
    when 1 then 'text-4xl font-bold mt-8 mb-4'
    when 2 then 'text-3xl font-bold mt-6 mb-3'
    when 3 then 'text-2xl font-semibold mt-5 mb-3'
    when 4 then 'text-xl font-semibold mt-4 mb-2'
    else 'text-lg font-semibold mt-3 mb-2'
    end
    "<h#{level} class=\"#{classes} text-gray-900\">#{children_html}</h#{level}>"
  end

  def process_list_node(node)
    list_type = node['tag'] == 'ul' ? 'ul' : 'ol'
    children_html = process_children(node)
    "<#{list_type} class=\"my-4 ml-6 text-gray-700\" #{list_type == 'ol' ? '' : 'style="list-style-type: disc"'}>#{children_html}</#{list_type}>"
  end

  def process_list_item_node(node)
    children_html = process_children(node)
    "<li class=\"my-2\">#{children_html}</li>"
  end

  def process_quote_node(node)
    children_html = process_children(node)
    "<blockquote class=\"border-l-4 border-gray-300 pl-4 py-2 my-4 italic text-gray-600 bg-gray-50 rounded-r\">#{children_html}</blockquote>"
  end

  def process_code_node(node)
    code = node['children']&.first&.dig('text') || ''
    language = node.dig('language') || ''
    escaped_code = CGI.escape_html(code)
    if language.present?
      "<pre class=\"bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto my-4 text-sm\"><code class=\"language-#{CGI.escape_html(language)}\">#{escaped_code}</code></pre>"
    else
      "<pre class=\"bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto my-4 text-sm\"><code>#{escaped_code}</code></pre>"
    end
  end

  def process_link_node(node)
    url = node['fields']&.dig('url') || node['href'] || '#'
    children_html = process_children(node)
    "<a href=\"#{CGI.escape_html(url)}\" target=\"_blank\" rel=\"noopener noreferrer\" class=\"text-blue-600 hover:underline\">#{children_html}</a>"
  end

  def process_image_node(node)
    src = node['fields']&.dig('src') || node['src'] || ''
    alt = node['fields']&.dig('alt') || node['alt'] || ''
    caption = node['fields']&.dig('caption') || node['caption'] || ''
    width = node['fields']&.dig('width') || node['width']
    height = node['fields']&.dig('height') || node['height']

    # Use blog title as default alt if no alt is provided
    alt = @blog_title if alt.blank? && @blog_title.present?

    # Extract filename from src URL as alt text if no alt is provided
    if alt.blank? && src.present?
      filename = File.basename(src)
      filename = File.basename(filename, '.*').gsub(/[_-]/, ' ')
      alt = filename.capitalize
    end

    # Build responsive image HTML with width/height
    attrs = "src=\"#{CGI.escape_html(src)}\" alt=\"#{CGI.escape_html(alt)}\" class=\"w-full h-auto object-cover rounded-lg\""
    attrs += " width=\"#{width}\"" if width.present?
    attrs += " height=\"#{height}\"" if height.present?

    image_html = "<img #{attrs} />"

    if caption.present?
      image_html = "<figure class=\"my-6\">#{image_html}<figcaption class=\"text-center text-sm text-gray-600 mt-2\">#{CGI.escape_html(caption)}</figcaption></figure>"
    else
      image_html = "<figure class=\"my-6\">#{image_html}</figure>"
    end

    image_html
  end

  def process_horizontal_rule_node(_node)
    '<hr class="my-8 border-t-2 border-gray-300" />'
  end

 def process_table_node(node)
    case node['type']
    when 'table'
      children_html = process_children(node)
      "<table class=\"w-full border-collapse border border-gray-300 my-4\">#{children_html}</table>"
    when 'tablerow'
      children_html = process_children(node)
      "<tr>#{children_html}</tr>"
    when 'tablecell'
      tag = node['header'] ? 'th' : 'td'
      children_html = process_children(node)
      attrs = node['colspan'] ? " colspan=\"#{node['colspan']}\"" : ''
      attrs += node['rowspan'] ? " rowspan=\"#{node['rowspan']}\"" : ''
      bg = node['header'] ? 'bg-gray-200' : 'bg-white'
      "<#{tag}#{attrs} class=\"border border-gray-300 px-4 py-2 #{bg} text-gray-700\">#{children_html}</#{tag}>"
    else
      process_children(node)
    end
  end

  def process_default_node(node)
    # Handle nodes with children
    if node['children'].is_a?(Array)
      process_children(node)
    else
      ''
    end
  end

  def process_children(node)
    return '' unless node['children'].is_a?(Array)

    node['children'].map { |child| process_node(child) }.join
  end
end
