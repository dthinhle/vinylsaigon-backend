# frozen_string_literal: true

module WordpressMigration
  class CategoryMapperService
    ATTRIBUTES_CSV_PATH = Rails.root.join('tmp', 'all_features.csv')
    PRODUCT_CATEGORIES_CSV_PATH = Rails.root.join('db', 'seeds', 'data', 'product_categories.csv')

    @product_category_mappings = nil

    ATTRIBUTE_TO_CHILD_CATEGORY_MAPPING = {
      'pa_headphone-type' => {
        'Over-Ear' => 'Over-Ear',
        'Full sized' => 'Over-Ear',
        'On-Ear' => 'On-Ear',
        'On ear' => 'On-Ear',
        'In-Ear' => 'In-Ear',
        'In ear' => 'In-Ear',
        'IEM' => 'In-Ear',
        'Earbud' => 'Earbud',
        'True Wireless' => 'Không dây',
        'True wireless' => 'Không dây',
        'Wireless' => 'Không dây',
        'Bluetooth' => 'Không dây',
        'Custom in ear' => 'In-Ear'
      },

      'pa_headphone-features' => {
        'Chống ồn' => 'Không dây',
        'Có micro' => 'Không dây',
        'Có tăng giảm âm lượng' => 'Không dây',
        'Không dây' => 'Không dây',
        'Tai nghe Gaming' => nil,
        'Tai nghe DJ' => nil,
        'Tai nghe phòng thu' => nil,
        'Tai nghe thể thao' => nil
      },

      'pa_headphone-cable-style' => {
        'Wireless' => 'Không dây',
        'True Wireless' => 'Không dây',
        'Bluetooth' => 'Không dây',
        'Wired' => nil,
        'Dây tháo rời' => nil,
        '2 pin' => nil,
        '2.5 mm' => nil,
        '4.4 mm' => nil,
        'MMCX' => nil,
        'Lightning' => nil
      },

      'pa_headphone-driver-style' => {
        'Dynamic' => nil,
        'Balanced Armature' => nil,
        'Planar Magnetic' => nil,
        'Electrotastic' => nil,
        'Active Balanced Magnetic' => nil
      },

      'pa_dac-amp-type' => {
        'Portable' => 'Portable DAC/AMP',
        'Portable DAC/AMP' => 'Portable DAC/AMP',
        'Portable DAC/Amp' => 'Portable DAC/AMP',
        'Portable Amplifier' => 'Portable DAC/AMP',
        'Desktop' => 'Desktop DAC/AMP',
        'Desktop DAC' => 'Desktop DAC/AMP',
        'Bluetooth' => 'Bluetooth DAC/AMP',
        'Bluetooth Receiver' => 'Bluetooth DAC/AMP',
        'Bluetooth Transmitter' => 'Bluetooth DAC/AMP',
        'Streaming DAC' => 'Bluetooth DAC/AMP',
        'Speaker Amplifier' => 'Speaker Amplifier',
        'Speakers Amplifier' => 'Speaker Amplifier',
        'Headphone Amplifier' => 'Desktop DAC/AMP',
        'Preamp' => 'Desktop DAC/AMP',
        'Transport' => 'Desktop DAC/AMP',
        'Amp' => 'Desktop DAC/AMP',
        'DAC' => 'Desktop DAC/AMP'
      },

      'pa_dac-amp-features' => {
        'Bluetooth' => 'Bluetooth DAC/AMP',
        'Streaming DAC' => 'Bluetooth DAC/AMP',
        'USB power supply' => nil,
        'Wifi' => nil,
        'Tích hợp Phono' => 'Phono stage',
        'Tube amp' => nil,
        'Solid amp' => nil,
        'R2R ladder DAC' => nil,
        'Pre Out' => nil,
        'Power Filter' => nil,
        'Digital Filter' => nil,
        'DSD Suport' => nil
      },

      'pa_phono-stage' => {
        'Phono stage' => 'Phono stage',
        '*' => 'Phono stage'
      },

      'pa_speaker-type' => {
        'Portable' => 'Loa Di Động',
        'Portable Speaker' => 'Loa Di Động',
        'Wireless' => 'Loa Di Động',
        'Wireless Speaker' => 'Loa Di Động',
        'Bluetooth' => 'Loa Di Động',
        'Bookshelf' => 'Loa Bookshelf',
        'Bookshelf Speaker' => 'Loa Bookshelf',
        'Active Speaker' => 'Loa Bookshelf',
        'Soundbar' => 'Soundbar',
        'Soundbars' => 'Soundbar',
        'Subwoofer' => 'Loa Subwoofer',
        'Floor Standing Speaker' => 'Loa Bookshelf',
        'Home Theater Speaker' => 'Loa Bookshelf',
        'Computer Speaker' => 'Loa Di Động',
        'Conference Speaker' => 'Loa Di Động',
        'Smart Home Speaker' => 'Loa Di Động'
      },

      'pa_speaker-features' => {
        'Bluetooth' => 'Loa Di Động',
        'Wifi' => 'Loa Di Động',
        'Airplay' => 'Loa Di Động',
        'Multi-room' => 'Loa Di Động',
        'Trợ lý ảo' => 'Loa Di Động',
        'Tích hợp Phono' => nil,
        'Tích hợp DAC' => nil,
        'Tích hợp Amply' => nil
      },

      'pa_speaker-cable-style' => {
        'Digital' => nil,
        'Analog' => nil,
        'Nguồn' => nil
      },

      'pa_dap-type' => {
        '24BIT Player' => 'Máy nghe nhạc',
        'DSD Player' => 'Máy nghe nhạc',
        'Loseless Player' => 'Máy nghe nhạc',
        '*' => 'Máy nghe nhạc'
      },

      'pa_dap-features' => {
        '*' => 'Máy nghe nhạc'
      },

      'pa_turntable' => {
        'Tích hợp Tonearm' => 'Mâm đĩa than',
        'Tích hợp Phono' => 'Mâm đĩa than',
        'Tích hợp Cartridge' => 'Mâm đĩa than',
        'Digital Output' => 'Mâm đĩa than',
        'Bluetooth' => 'Mâm đĩa than',
        '*' => 'Mâm đĩa than'
      },

      'pa_cartridge' => {
        'MM' => 'Kim đĩa than',
        'MC' => 'Kim đĩa than',
        '*' => 'Kim đĩa than'
      },

      'pa_day-2' => {
        'Dây USB' => 'Phụ kiện khác',
        'Dây optical' => 'Phụ kiện khác',
        'Dây Loa' => 'Phụ kiện khác',
        'Dây IC' => 'Phụ kiện khác',
        'Dây Coaxial' => 'Phụ kiện khác',
        '*' => 'Dây Tai nghe'
      },

      'pa_headphones-cable' => {
        'Bluetooth cable' => 'Dây Tai nghe',
        'Apple Lightning cable' => 'Dây Tai nghe',
        '2-pin connector' => 'Dây Tai nghe',
        '2.5mm connector' => 'Dây Tai nghe',
        '3.5mm connector' => 'Dây Tai nghe',
        '4.4mm' => 'Dây Tai nghe',
        'MMCX connector' => 'Dây Tai nghe',
        '*' => 'Dây Tai nghe'
      },

      'pa_headphones-connector' => {
        '2-pin' => 'Dây Tai nghe',
        'MMCX' => 'Dây Tai nghe',
        '*' => 'Dây Tai nghe'
      },

      'pa_ear-tips' => {
        'Silicon' => 'Phụ kiện khác',
        '*' => 'Phụ kiện khác'
      },

      'pa_ear-pads' => {
        '*' => 'Phụ kiện khác'
      },

      'pa_hop-dung' => {
        '*' => 'Hộp đựng'
      },

      'pa_jack' => {
        '2.5 mm' => 'Phụ kiện khác',
        '3.5 mm' => 'Phụ kiện khác',
        '4.4 mm' => 'Phụ kiện khác',
        '6.3 mm' => 'Phụ kiện khác',
        'XLR' => 'Phụ kiện khác',
        'RCA' => 'Phụ kiện khác',
        '*' => 'Phụ kiện khác'
      },

      'pa_phu-kien-khac' => {
        '*' => 'Phụ kiện khác'
      },

      'pa_music-server' => {
        'Music Server' => 'Phụ kiện khác',
        '*' => 'Phụ kiện khác'
      },

      'pa_loc-nhieu' => {
        'Lọc nhiễu' => 'Phụ kiện khác',
        '*' => 'Phụ kiện khác'
      },

      'pa_chong-rung' => {
        'Loa' => 'Phụ kiện khác',
        'Kệ' => 'Phụ kiện khác',
        '*' => 'Phụ kiện khác'
      }
    }.freeze

    CATEGORY_ASSIGNMENT_PRIORITY = {
      'Tai nghe' => [
        'pa_headphone-type',
        'pa_headphone-cable-style',
        'pa_headphone-driver-style',
        'pa_headphone-features',
      ],

      'DAC/AMP' => [
        'pa_phono-stage',
        'pa_dac-amp-type',
        'pa_dac-amp-features',
      ],

      'Loa' => [
        'pa_speaker-type',
        'pa_speaker-features',
        'pa_speaker-cable-style',
      ],

      'Nguồn phát' => [
        'pa_turntable',
        'pa_dap-type',
        'pa_dap-features',
        'pa_cartridge',
      ],

      'Phụ kiện' => [
        'pa_hop-dung',
        'pa_day-2',
        'pa_headphones-cable',
        'pa_headphones-connector',
        'pa_ear-tips',
        'pa_ear-pads',
        'pa_jack',
        'pa_phu-kien-khac',
        'pa_music-server',
        'pa_loc-nhieu',
        'pa_chong-rung',
      ]
    }.freeze

    class << self
      def product_category_mappings
        @product_category_mappings ||= begin
          return {} unless File.exist?(PRODUCT_CATEGORIES_CSV_PATH)

          csv_rows = CSV.read(PRODUCT_CATEGORIES_CSV_PATH, headers: true)
          csv_rows.to_h { |row| [row['wp_id'].to_s, row['product_category']] }
        rescue StandardError => e
          Rails.logger.error("Failed to load product-categories CSV: #{e.message}")
          {}
        end
      end

      def reset_product_category_mappings!
        @product_category_mappings = nil
      end

      def product_category_for(wp_id)
        return nil if wp_id.blank?

        product_category_mappings[wp_id.to_s]
      end

      def attributes_mappings
        @attributes_mappings ||= begin
          return {} unless File.exist?(ATTRIBUTES_CSV_PATH)

          csv_rows = CSV.read(ATTRIBUTES_CSV_PATH)
          unless csv_rows.empty?
            csv_rows.shift
            csv_rows.group_by(&:first).transform_values { |rows| rows.to_h { |_, *_, attribute_value, _, attribute_type| [attribute_type, attribute_value] } }
          else
            {}
          end
        rescue StandardError => e
          Rails.logger.error("Failed to load attributes CSV: #{e.message}")
          {}
        end
      end
    end

    def self.determine_category(wc_product)
      csv_category_name = product_category_for(wc_product['id'])
      if csv_category_name.present?
        csv_category = find_category(csv_category_name)
        return csv_category if csv_category
      end

      root_category = map_root_category(wc_product['categories']&.first)
      return unless root_category

      child_category = determine_child_category(wc_product, root_category)
      child_category || root_category
    end

    def self.map_root_category(wc_category)
      return nil unless wc_category

      case wc_category['slug']
      when 'headphone', 'tai-nghe'
        find_category('Tai nghe')
      when 'dac-amp'
        find_category('DAC/AMP')
      when 'dap', 'analog-vinyl', 'vinyl-analog'
        find_category('Nguồn phát')
      when 'speaker', 'loa'
        find_category('Loa')
      when 'home-studio'
        find_category('Home Studio')
      when 'phu-kien'
        find_category('Phụ kiện')
      else
        nil
      end
    end

    def self.determine_child_category(wc_product, root_category)
      special_case = handle_special_cases(wc_product, root_category)
      return special_case if special_case

      determine_child_category_with_priority(wc_product)
    end

    def self.priority_list
      CATEGORY_ASSIGNMENT_PRIORITY.values.flatten.uniq
    end

    def self.determine_child_category_with_priority(wc_product)
      attr_list = priority_list
      attributes = extract_attributes(wc_product)
      Rails.logger.debug { "Attributes: #{attributes}" } unless attributes.empty?

      attr_list.each do |attribute_slug|
        attr = attributes[attribute_slug]
        next unless attr

        mapping = ATTRIBUTE_TO_CHILD_CATEGORY_MAPPING[attribute_slug]
        next unless mapping

        if mapping.key?(attr)
          child = find_category(mapping[attr])
          return child if child
        elsif mapping.key?('*')
          child = find_category(mapping['*'])
          return child if child
        end
      end

      nil
    end

    def self.handle_special_cases(wc_product, root_category)
      attributes = extract_attributes(wc_product)
      Rails.logger.debug { "Attributes: #{attributes}" } unless attributes.empty?

      if root_category.title == 'Tai nghe'
        cable_style = attributes['pa_headphone-cable-style'] || []
        if cable_style.any? { |v| v.match?(/wireless|bluetooth/i) }
          return find_child_category(root_category, 'Không dây')
        end
      end

      if attributes.key?('pa_phono-stage') && attributes['pa_phono-stage'].any?
        return find_child_category(root_category, 'Phono stage')
      end

      if attributes.key?('pa_cartridge') && attributes['pa_cartridge'].any?
        accessories = find_category('Phụ kiện')
        return find_child_category(accessories, 'Kim đĩa than') if accessories
      end

      nil
    end

    def self.extract_attributes(wc_product)
      attributes_mappings.fetch(wc_product['id'].to_s, {})
    end

    def self.find_category(name)
      Category.find_by(title: name)
    end
  end
end
