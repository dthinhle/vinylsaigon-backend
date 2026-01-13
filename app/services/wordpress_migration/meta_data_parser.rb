# frozen_string_literal: true

module WordpressMigration
  # Service for parsing WordPress meta_data into product_attributes JSONB
  class MetaDataParser
    attr_reader :product_attributes, :meta_title, :meta_description, :gift_content, :flags, :warranty, :youtube_ids

    YOUTUBE_LINK_REGEX = /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})(?:[?&]si=[^&\s]*)?/

    def initialize(meta_data)
      @meta_data = meta_data || []
      @product_attributes = {}
      @meta_title = nil
      @meta_description = nil
      @gift_content = nil
      @warranty = nil
      @flags = []
      @block_info = {}
      @youtube_ids = []
    end

    def parse!
      @meta_data.each do |meta|
        key = meta['key']
        value = meta['value']

        case key
        when 'bao_hanh'
          @warranty = parse_warranty(value)
        when 'qua_tang'
          @gift_content = value
        when 'sp_sap_ve'
          @flags << Product::FLAGS[:arrive_soon] if truthy?(value)
        when '_yoast_wpseo_title'
          value = value.gsub(/\|?(?:Hỗ trợ)? ?Trả Góp 0\%/i, '').strip
          @meta_title = value.gsub(/ ?\|* ?3KShop(?:\.vn)?\|*$/i, '').strip
        when '_yoast_wpseo_metadesc'
          @meta_description = value
        else
          if key.include?('block_thong_tin')
            parse_block_info(key, value)
          end
        end
      end

      # Process block info into structured format
      process_block_info
      @product_attributes.filter! { |_, v| v.present? }
      @product_attributes.transform_values!(&:strip)

      self
    end

    private

    def parse_warranty(value)
      return nil if value.blank?

      if value.downcase.include?('tháng')
        match = value.match(/(\d+)\s*tháng/i)
        match[1].to_i if match
      elsif value.downcase.include?('năm')
        match = value.match(/(\d+)\s*năm/i)
        match[1].to_i * 12 if match
      end
    end

    def parse_block_info(key, value)
      # Format: block_thong_tin_{block}_{dong}_{field}
      # Example: block_thong_tin_0_dong_0_name, block_thong_tin_0_dong_0_noi_dung
      if key.match(/^block_thong_tin_(\d+)_video/)
        return parse_youtube_embed(key, value)
      end
      match = key.match(/^block_thong_tin_(\d+)_dong_(\d+)_(.+)/)
      return unless match

      block_num = match[1].to_i
      dong_num = match[2].to_i
      field = match[3]

      @block_info[block_num] ||= {}
      @block_info[block_num][dong_num] ||= {}
      @block_info[block_num][dong_num][field] = value
    end

    def parse_youtube_embed(key, value)
      # Format: _oembed_{index}
      match = key.match(/^_oembed_(\d+)/)
      return unless match
      value = value.match(YOUTUBE_LINK_REGEX)
      return unless value

      youtube_id = value[1]
      @youtube_ids << youtube_id unless youtube_ids.include?(youtube_id)
    end

    def process_block_info
      return if @block_info.empty?

      @block_info.each do |_block_num, fields|
        fields.each do |_index, field_values|
          next unless field_values['name'].present? && field_values['noi_dung'].present?

          @product_attributes[field_values['name']] = field_values['noi_dung']
        end
      end
    end

    def truthy?(value)
      return false if value.nil? || value == false

      value.to_s.downcase.in?(['true', 'yes', '1', 'on'])
    end
  end
end
