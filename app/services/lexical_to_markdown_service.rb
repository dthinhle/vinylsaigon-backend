# frozen_string_literal: true

# Service to convert Lexical format JSON to Markdown
class LexicalToMarkdownService
  FORMAT_CONSTANTS = {
    NORMAL: 0,
    BOLD: 1,
    ITALIC: 2,
    ITALIC_BOLD: 3,
    UNDERLINE_BOLD: 9,
    UNDERLINE_ITALIC: 10,
    UNDERLINE_ITALIC_BOLD: 11
  }.freeze

  class << self
    # Main entry point to convert Lexical JSON to Markdown
    # @param lexical_json [Hash] The Lexical format JSON structure
    # @return [String] Markdown formatted string
    def call(lexical_json)
      return '' if lexical_json.blank?

      data = lexical_json.is_a?(String) ? JSON.parse(lexical_json) : lexical_json

      root = data.is_a?(Hash) && data['root'] ? data['root'] : data

      return '' unless root.is_a?(Hash) && root['children']

      convert_children(root['children'])
    end

    private

    def convert_children(children, context: {})
      return '' unless children.is_a?(Array)

      children.map { |child| convert_node(child, context: context) }.join
    end

    def convert_node(node, context: {})
      return '' if node.nil? || !node.is_a?(Hash)

      case node['type']
      when 'root'
        convert_children(node['children'], context: context)
      when 'paragraph'
        convert_paragraph(node)
      when 'text'
        convert_text(node, context: context)
      when 'link'
        convert_link(node)
      when 'heading'
        convert_heading(node)
      when 'list'
        convert_list(node)
      when 'listitem'
        convert_list_item(node, context: context)
      when 'image'
        convert_image(node)
      when 'youtube'
        convert_youtube(node)
      when 'video'
        convert_video(node)
      when 'linebreak'
        convert_linebreak
      else
        Rails.logger.warn("Unknown Lexical node type: #{node['type']}")
        ''
      end
    end

    def convert_paragraph(node)
      children = node['children'] || []
      content = convert_children(children)

      return '' if content.strip.empty?

      "#{content}\n\n"
    end

    def convert_text(node, context: {})
      text = node['text'] || ''
      return '' if text.empty?

      format = node['format'] || FORMAT_CONSTANTS[:NORMAL]

      formatted_text = apply_text_formatting(text, format)

      context[:in_link] ? text : formatted_text
    end

    def apply_text_formatting(text, format)
      case format
      when FORMAT_CONSTANTS[:BOLD]
        "**#{text}**"
      when FORMAT_CONSTANTS[:ITALIC]
        "*#{text}*"
      when FORMAT_CONSTANTS[:ITALIC_BOLD]
        "***#{text}***"
      when FORMAT_CONSTANTS[:UNDERLINE_BOLD]
        "**#{text}**"
      when FORMAT_CONSTANTS[:UNDERLINE_ITALIC]
        "*#{text}*"
      when FORMAT_CONSTANTS[:UNDERLINE_ITALIC_BOLD]
        "***#{text}***"
      else
        text
      end
    end

    def convert_link(node)
      url = node['url'] || ''
      children = node['children'] || []

      link_text = convert_children(children, context: { in_link: true })

      return '' if link_text.strip.empty?

      "[#{link_text}](#{url})"
    end

    def convert_heading(node)
      tag = node['tag'] || 'h1'
      children = node['children'] || []

      content = convert_children(children)
      return '' if content.strip.empty?

      "#{('#' * level)} #{content.strip}\n\n"
    end

    def convert_list(node)
      list_type = node['listType'] || 'bullet'
      tag = node['tag'] || 'ul'
      children = node['children'] || []

      context = {
        list_type: list_type,
        list_tag: tag,
        item_index: 0
      }

      list_content = children.map.with_index do |child, index|
        context[:item_index] = index
        convert_node(child, context: context)
      end.join

      "#{list_content}\n"
    end

    def convert_list_item(node, context: {})
      children = node['children'] || []
      content = convert_children(children, context: context)

      return '' if content.strip.empty?

      list_type = context[:list_type] || 'bullet'
      item_index = context[:item_index] || 0

      if list_type == 'bullet'
        "- #{content.strip}\n"
      else
        "#{item_index + 1}. #{content.strip}\n"
      end
    end

    def convert_image(node)
      src = node['src'] || ''
      alt_text = node['altText'] || ''

      return '' if src.empty?

      "![#{alt_text}](#{src})\n\n"
    end

    def convert_youtube(node)
      video_id = node['videoID'] || ''

      return '' if video_id.empty?

      youtube_url = "https://www.youtube.com/watch?v=#{video_id}"
      "[![YouTube Video](https://img.youtube.com/vi/#{video_id}/0.jpg)](#{youtube_url})\n\n"
    end

    def convert_video(node)
      src = node['src'] || ''

      return '' if src.empty?

      "<video src=\"#{src}\" controls></video>\n\n"
    end

    def convert_linebreak
      "  \n"
    end
  end
end
