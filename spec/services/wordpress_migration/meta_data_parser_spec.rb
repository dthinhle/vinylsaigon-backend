# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WordpressMigration::MetaDataParser do
  describe '#parse!' do
    it 'extracts warranty information' do
      meta_data = [
        { 'key' => 'bao_hanh', 'value' => '12 tháng chính hãng' },
      ]

      parser = described_class.new(meta_data)
      parser.parse!

      expect(parser.warranty).to eq('12 tháng chính hãng')
      expect(parser.product_attributes['bao_hanh']).to eq('12 tháng chính hãng')
    end

    it 'extracts gift content' do
      meta_data = [
        { 'key' => 'qua_tang', 'value' => 'Case da cao cấp + Cleaning kit' },
      ]

      parser = described_class.new(meta_data)
      parser.parse!

      expect(parser.gift_content).to eq('Case da cao cấp + Cleaning kit')
    end

    it 'adds arrive_soon flag when sp_sap_ve is truthy' do
      meta_data = [
        { 'key' => 'sp_sap_ve', 'value' => 'yes' },
      ]

      parser = described_class.new(meta_data)
      parser.parse!

      expect(parser.flags).to include('arrive_soon')
    end

    it 'does not add arrive_soon flag when sp_sap_ve is falsy' do
      meta_data = [
        { 'key' => 'sp_sap_ve', 'value' => 'no' },
      ]

      parser = described_class.new(meta_data)
      parser.parse!

      expect(parser.flags).not_to include('arrive_soon')
    end

    it 'extracts Yoast SEO meta title' do
      meta_data = [
        { 'key' => '_yoast_wpseo_title', 'value' => 'Noble Audio - Premium IEM' },
      ]

      parser = described_class.new(meta_data)
      parser.parse!

      expect(parser.meta_title).to eq('Noble Audio - Premium IEM')
    end

    it 'extracts Yoast SEO meta description' do
      meta_data = [
        { 'key' => '_yoast_wpseo_metadesc', 'value' => 'Best in-ear monitors' },
      ]

      parser = described_class.new(meta_data)
      parser.parse!

      expect(parser.meta_description).to eq('Best in-ear monitors')
    end

    it 'parses block_thong_tin structured data' do
      meta_data = [
        { 'key' => 'block_thong_tin_0_dong_0_name', 'value' => 'Driver' },
        { 'key' => 'block_thong_tin_0_dong_0_noi_dung', 'value' => '1DD + 4BA Hybrid' },
        { 'key' => 'block_thong_tin_0_dong_1_name', 'value' => 'Frequency Response' },
        { 'key' => 'block_thong_tin_0_dong_1_noi_dung', 'value' => '10Hz - 40kHz' },
      ]

      parser = described_class.new(meta_data)
      parser.parse!

      block_info = parser.product_attributes['block_thong_tin']
      expect(block_info).to be_present
      expect(block_info[0]['items']).to include(
        { 'name' => 'Driver', 'noi_dung' => '1DD + 4BA Hybrid' }
      )
      expect(block_info[0]['items']).to include(
        { 'name' => 'Frequency Response', 'noi_dung' => '10Hz - 40kHz' }
      )
    end

    it 'handles multiple blocks in block_thong_tin' do
      meta_data = [
        { 'key' => 'block_thong_tin_0_dong_0_name', 'value' => 'Block 0 Field' },
        { 'key' => 'block_thong_tin_0_dong_0_noi_dung', 'value' => 'Block 0 Value' },
        { 'key' => 'block_thong_tin_1_dong_0_name', 'value' => 'Block 1 Field' },
        { 'key' => 'block_thong_tin_1_dong_0_noi_dung', 'value' => 'Block 1 Value' },
      ]

      parser = described_class.new(meta_data)
      parser.parse!

      block_info = parser.product_attributes['block_thong_tin']
      expect(block_info.size).to eq(2)
    end

    it 'handles nil meta_data' do
      parser = described_class.new(nil)
      parser.parse!

      expect(parser.product_attributes).to eq({})
      expect(parser.flags).to eq([])
    end

    it 'handles empty meta_data' do
      parser = described_class.new([])
      parser.parse!

      expect(parser.product_attributes).to eq({})
      expect(parser.flags).to eq([])
    end
  end
end
