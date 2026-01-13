# frozen_string_literal: true

module CurrencyHelper
  # Canonical VND formatter used across views and mailers.
  # Accepts integer or numeric-like values (cents/units already in VND as integers).
  # Returns '0₫' for nil/0, otherwise "10,000₫".
  def format_vnd_currency(vnd)
    return '0₫' if vnd.nil? || vnd.to_i.zero?

    "#{number_with_delimiter(vnd.to_i)}₫"
  end
end
