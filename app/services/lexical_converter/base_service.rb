# frozen_string_literal: true

module LexicalConverter
  class BaseService
    FORMAT_CONSTANTS = {
      NORMAL: 0,
      BOLD: 1,
      ITALIC: 2,
      ITALIC_BOLD: 3,
      UNDERLINE_BOLD: 9,
      UNDERLINE_ITALIC: 10,
      UNDERLINE_ITALIC_BOLD: 11
    }.freeze

    attr_reader :lexical_json

    def initialize(lexical_json)
      @lexical_json = lexical_json
    end

    def call
      return '' if lexical_json.blank?

      data = lexical_json.is_a?(String) ? JSON.parse(lexical_json) : lexical_json

      root = data.is_a?(Hash) && data['root'] ? data['root'] : data

      return '' unless root.is_a?(Hash) && root['children']

      convert_children(root['children'])
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse Lexical JSON: #{e.message}")
      lexical_json
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
      node['text'] || ''
    end

    def convert_link(node)
      children = node['children'] || []
      convert_children(children, context: { in_link: true })
    end

    def convert_heading(node)
      children = node['children'] || []
      content = convert_children(children)
      return '' if content.strip.empty?

      "#{content.strip}\n\n"
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

      "- #{content.strip}\n"
    end

    def convert_image(node)
      alt_text = node['altText'] || ''
      alt_text.present? ? "[Image: #{alt_text}]\n\n" : "[Image]\n\n"
    end

    def convert_youtube(node)
      video_id = node['videoID'] || ''
      return '' if video_id.empty?

      "[YouTube Video: https://youtu.be/#{video_id}]\n\n"
    end

    def convert_video(node)
      src = node['src'] || ''
      return '' if src.empty?

      "[Video: #{src}]\n\n"
    end

    def convert_linebreak
      "\n"
    end
  end
end
