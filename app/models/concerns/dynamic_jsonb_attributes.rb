# frozen_string_literal: true

module DynamicJsonbAttributes
  extend ActiveSupport::Concern

  class_methods do
    def dynamic_jsonb_attribute(attr_name)
      @dynamic_jsonb_attribute_name = attr_name.to_sym

      define_method(:dynamic_jsonb_attribute_name) do
        self.class.instance_variable_get(:@dynamic_jsonb_attribute_name) || :variant_attributes
      end

      define_method(:dynamic_jsonb_attributes) do
        value = self[dynamic_jsonb_attribute_name]
        case value
        when String
          JSON.parse(value) rescue {}
        when Hash
          value
        else
          {}
        end
      end

      define_method(:dynamic_jsonb_attributes=) do |attrs|
        self[dynamic_jsonb_attribute_name] = attrs.is_a?(String) ? JSON.parse(attrs) : attrs
      end

      define_method(:normalize_dynamic_jsonb_attributes) do
        self[dynamic_jsonb_attribute_name] = dynamic_jsonb_attributes.presence
      end

      define_method(:array_format?) do |attrs|
        attrs.is_a?(Hash) && attrs.key?('attributes') && attrs['attributes'].is_a?(Array)
      end

      define_method(:validate_dynamic_jsonb_attributes) do
        attrs = dynamic_jsonb_attributes
        return if attrs.blank?

        keys = attrs.keys
        if keys.any? { |k| k.blank? }
          errors.add(dynamic_jsonb_attribute_name, 'Keys must not be empty')
        end
        if keys.map(&:downcase).uniq.length != keys.length
          errors.add(dynamic_jsonb_attribute_name, 'Keys must be unique (case-insensitive)')
        end

        return if array_format?(attrs)

        attrs.each do |k, v|
          unless v.is_a?(String) || v.is_a?(Numeric) || v == true || v == false
            errors.add(dynamic_jsonb_attribute_name, 'Values must be string, number, or boolean')
          end
          if v.is_a?(String)
            if v.blank?
              errors.add(dynamic_jsonb_attribute_name, 'String values must not be empty')
            end
          end
        end
      end

      validate :validate_dynamic_jsonb_attributes
      before_save :normalize_dynamic_jsonb_attributes
    end
  end
end
