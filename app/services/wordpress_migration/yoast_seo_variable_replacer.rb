# frozen_string_literal: true

module WordpressMigration
  # Service to replace Yoast SEO template variables with actual content
  # Handles variables like %%title%%, %%page%%, %%sep%%, etc.
  class YoastSeoVariableReplacer
    SEPARATOR = '-'
    SITE_NAME = 'Vinyl Saigon'

    class << self
      # Replace Yoast SEO variables in text with actual values
      # @param text [String] Text containing Yoast variables
      # @param context [Hash] Context data for replacement
      #   - :title [String] Post title
      #   - :excerpt [String] Post excerpt
      #   - :category [String] Category name
      #   - :page [Integer] Page number (optional, defaults to nil)
      # @return [String] Text with variables replaced
      def replace(text, context = {})
        return text if text.blank?
        return text unless text.include?('%%')

        result = text.dup

        # Replace all supported variables
        result.gsub!('%%title%%', context[:title].to_s)
        result.gsub!('%%sep%%', SEPARATOR)
        result.gsub!('%%sitename%%', SITE_NAME)
        result.gsub!('%%category%%', context[:category].to_s)
        result.gsub!('%%excerpt%%', context[:excerpt].to_s)
        result.gsub!('%%currentyear%%', Time.current.year.to_s)
        result.gsub!('%%currentmonth%%', Time.current.strftime('%B'))

        # Page number - only show if > 1
        if context[:page].to_i > 1
          result.gsub!('%%page%%', "Page #{context[:page]}")
        else
          # Remove %%page%% and any surrounding whitespace
          result.gsub!(/\s*%%page%%\s*/, '')
        end

        # Clean up any remaining variables that weren't replaced
        result.gsub!(/%%\w+%%/, '')

        # Clean up extra whitespace
        result.strip!

        result
      end

      # Check if text contains Yoast variables
      # @param text [String] Text to check
      # @return [Boolean] True if text contains %% variables
      def contains_variables?(text)
        text.present? && text.include?('%%')
      end
    end
  end
end
