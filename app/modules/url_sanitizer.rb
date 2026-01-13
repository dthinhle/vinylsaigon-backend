# frozen_string_literal: true

# UrlSanitizer module provides methods to sanitize and validate URLs
# for sitemap generation, preventing double slashes and null values
module UrlSanitizer
  extend self

  # Sanitizes a path by removing leading slashes and handling null/empty values
  #
  # @param path [String, nil] the path to sanitize
  # @return [String] the sanitized path
  def sanitize_path(path)
    return '' if path.blank?

    # Remove leading slashes and ensure single leading slash if needed
    path = path.to_s.gsub(/^\//, '')

    # Remove double slashes and normalize
    path.gsub(/\/+/, '/')
  end

 # Validates if a path is suitable for sitemap inclusion
 #
 # @param path [String, nil] the path to validate
 # @return [Boolean] true if path is valid for sitemap inclusion
 def valid_path?(path)
    return false if path.blank?

    sanitized = sanitize_path(path)

    # Path should not be empty after sanitization
    return false if sanitized.empty?

    # Path should not contain invalid patterns
    invalid_patterns = [
      /^\./,           # starts with dot
      /\/\.\.\//,      # contains ../
      /\/\.\//,        # contains ./
      /\/$/,           # ends with slash (except for root)
      /\/{2,}/,        # contains double slashes
      /%00/,           # null byte
      /<|>/,            # contains HTML tags
    ]

    invalid_patterns.none? { |pattern| sanitized.match?(pattern) }
  end

 # Sanitizes and validates a path in one operation
 #
 # @param path [String, nil] the path to process
 # @return [String, nil] the sanitized path if valid, nil otherwise
 def process_path(path)
    sanitized = sanitize_path(path)
    return nil unless valid_path?(sanitized)

    sanitized
 end
end
