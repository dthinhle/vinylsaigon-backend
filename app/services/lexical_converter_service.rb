# frozen_string_literal: true

# Service to convert Lexical format JSON to Markdown or Plain Text
class LexicalConverterService
  class << self
    # Main entry point to convert Lexical JSON
    # @param lexical_json [Hash|String] The Lexical format JSON structure
    # @param format [Symbol] :markdown or :plain_text
    # @return [String] Formatted string
    def call(lexical_json, format: :markdown)
      service_class = case format
      when :markdown
                        LexicalConverter::MarkdownService
      when :plain_text
                        LexicalConverter::BaseService
      else
                        raise ArgumentError, "Unknown format: #{format}"
      end

      service_class.new(lexical_json).call
    end
  end
end
