# frozen_string_literal: true

# Service for reading system-wide configuration values stored in SystemConfig.
# Minimal, defensive API with thread-safe memoization.
class SystemConfigService
  @cache = {}
  @mutex = Mutex.new

  class << self
    # Returns Float (0..100) or nil
    def max_discount_percent
      fetch_float('maxDiscountPercent')
    end

    # Returns Integer or nil
    def max_discount_per_day
      fetch_integer('maxDiscountPerDay')
    end

    # Returns Integer or nil
    def max_discount_per_user_per_day
      fetch_integer('maxDiscountPerUserPerDay')
    end

    # Returns boolean. If explicit config 'enforcementEnabled' exists, use it.
    # Otherwise, consider enforcement enabled when a max_discount_percent is configured.
    def enforcement_enabled?
      val = fetch_string('enforcementEnabled')
      return ActiveModel::Type::Boolean.new.cast(val) unless val.nil?

      !max_discount_percent.nil?
    end

    private

    def fetch_string(name)
      read_config(name)
    end

    def fetch_integer(name)
      str = read_config(name)
      return nil if str.nil?

      normalized = str.to_s.strip.gsub(/[^\d\-]/, '')
      Integer(normalized)
    rescue => e
      Rails.logger.warn("[SystemConfigService] failed to parse integer #{name}: #{e.class} #{e.message}")
      nil
    end

    def fetch_float(name)
      str = read_config(name)
      return nil if str.nil?

      s = strip_percent(str.to_s.strip)
      Float(s)
    rescue => e
      Rails.logger.warn("[SystemConfigService] failed to parse float #{name}: #{e.class} #{e.message}")
      nil
    end

    def strip_percent(s)
      s.end_with?('%') ? s[0...-1] : s
    end

    # Read config by case-insensitive name and memoize.
    def read_config(name)
      key = name.to_s.downcase
      @mutex.synchronize do
        return @cache[key] if @cache.key?(key)

        cfg = SystemConfig.where('lower(name) = ?', name.to_s.downcase).first
        val = cfg&.value
        @cache[key] = val
        val
      end
    rescue => e
      Rails.logger.error("[SystemConfigService] read_config error for #{name}: #{e.class} #{e.message}")
      nil
    end

    # Clear in-memory cache (useful for console / tests). Not used automatically.
    def clear_cache!
      @mutex.synchronize { @cache.clear }
    end
  end
end
