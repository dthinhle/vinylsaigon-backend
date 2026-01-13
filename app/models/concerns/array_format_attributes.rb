# frozen_string_literal: true

module ArrayFormatAttributes
  extend ActiveSupport::Concern

  included do
    def new_format?(attr_name)
      attrs = send(attr_name)
      return false unless attrs.is_a?(Hash)
      attrs.key?('attributes') && attrs['attributes'].is_a?(Array)
    end

    def normalized_attributes(attr_name)
      # TODO: Remove old format support after migration complete
      attrs = send(attr_name)
      return [] if attrs.blank?

      if new_format?(attr_name)
        attrs['attributes'] || []
      else
        attrs.map { |k, v| { 'name' => k, 'value' => v } }
      end
    end

    def attributes_for_display(attr_name)
      normalized_attributes(attr_name).each do |attr|
        yield(attr['name'], attr['value']) if block_given?
      end
    end

    def validate_array_format_attributes(attr_name)
      attrs = send(attr_name)
      return if attrs.blank?

      if new_format?(attr_name)
        attributes_array = attrs['attributes']
        return if attributes_array.blank?

        names = attributes_array.map { |attr| attr['name']&.to_s }.compact
        if names.any?(&:blank?)
          errors.add(attr_name, 'Attribute names must not be empty')
        end
        if names.map(&:downcase).uniq.length != names.length
          errors.add(attr_name, 'Attribute names must be unique (case-insensitive)')
        end

        attributes_array.each do |attr|
          value = attr['value']
          unless value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
            errors.add(attr_name, 'Values must be string, number, or boolean')
          end
          if value.is_a?(String) && value.blank?
            errors.add(attr_name, 'String values must not be empty')
          end
        end
      end
    end
  end
end
