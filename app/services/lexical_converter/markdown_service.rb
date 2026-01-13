# frozen_string_literal: true

module LexicalConverter
  class MarkdownService < BaseService
    private

    # Convert text node with formatting
    def convert_text(node, context: {})
      text = node['text'] || ''
      return '' if text.empty?

      format = node['format'] || FORMAT_CONSTANTS[:NORMAL]

      # Apply formatting based on format constant
      formatted_text = apply_text_formatting(text, format)

      # If we're inside a link, don't apply additional formatting
      context[:in_link] ? text : formatted_text
    end

    # Apply markdown formatting based on Lexical format constant
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

    # Convert link node
    def convert_link(node)
      url = node['url'] || ''
      children = node['children'] || []

      # Get link text from children
      link_text = convert_children(children, context: { in_link: true })

      return '' if link_text.strip.empty?

      "[#{link_text}](#{url})"
    end

    # Convert heading node
    def convert_heading(node)
      tag = node['tag'] || 'h1'
      children = node['children'] || []

      content = convert_children(children)
      return '' if content.strip.empty?

      level = tag[1].to_i # Extract number from h1, h2, etc.
      "#{('#' * level)} #{content.strip}\n\n"
    end

    # Convert list item node
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

    # Convert image node
    def convert_image(node)
      src = node['src'] || ''
      alt_text = node['altText'] || ''

      return '' if src.empty?

      "![#{alt_text}](#{src})\n\n"
    end

    # Convert YouTube node
    def convert_youtube(node)
      video_id = node['videoID'] || ''

      return '' if video_id.empty?

      youtube_url = "https://www.youtube.com/watch?v=#{video_id}"
      "[![YouTube Video](https://img.youtube.com/vi/#{video_id}/0.jpg)](#{youtube_url})\n\n"
    end

    # Convert video node
    def convert_video(node)
      src = node['src'] || ''

      return '' if src.empty?

      "<video src=\"#{src}\" controls></video>\n\n"
    end

    # Convert linebreak node
    def convert_linebreak
      "  \n"
    end
  end
end
