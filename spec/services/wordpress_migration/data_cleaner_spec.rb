# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WordpressMigration::DataCleaner do
  describe '.clean_html' do
    it 'returns empty string for nil input' do
      expect(described_class.clean_html(nil)).to eq('')
    end

    it 'returns empty string for blank input' do
      expect(described_class.clean_html('')).to eq('')
    end

    it 'converts absolute URLs to relative paths' do
      html = '<p><img src="https://3kshop.vn/wp-content/uploads/2023/image.jpg" /></p>'
      result = described_class.clean_html(html)
      expect(result).to include('/uploads/2023/image.jpg')
      expect(result).not_to include('https://3kshop.vn')
    end

    it 'strips width and height attributes from images' do
      html = '<img src="/test.jpg" width="600" height="400" />'
      result = described_class.clean_html(html)
      expect(result).not_to include('width="600"')
      expect(result).not_to include('height="400"')
    end

    it 'removes empty paragraphs' do
      html = '<p>Content</p><p></p><p>More content</p>'
      result = described_class.clean_html(html)
      expect(result).to eq('<p>Content</p><p>More content</p>')
    end

    it 'normalizes whitespace' do
      html = "  <p>Content</p>  \n  "
      result = described_class.clean_html(html)
      expect(result).to eq('<p>Content</p>')
    end
  end

  describe '.extract_image_urls' do
    it 'returns empty array for nil input' do
      expect(described_class.extract_image_urls(nil)).to eq([])
    end

    it 'extracts image URLs from HTML' do
      html = '<p><img src="https://example.com/image1.jpg" /><img src="/image2.png" /></p>'
      result = described_class.extract_image_urls(html)
      expect(result).to eq(['https://example.com/image1.jpg', '/image2.png'])
    end

    it 'handles single quotes in image tags' do
      html = "<img src='https://example.com/image.jpg' />"
      result = described_class.extract_image_urls(html)
      expect(result).to eq(['https://example.com/image.jpg'])
    end
  end

  describe '.convert_absolute_urls' do
    it 'converts wp-content URLs' do
      html = 'https://3kshop.vn/wp-content/uploads/2023/file.jpg'
      result = described_class.convert_absolute_urls(html)
      expect(result).to eq('/uploads/2023/file.jpg')
    end

    it 'converts product URLs' do
      html = 'https://3kshop.vn/product/my-product/'
      result = described_class.convert_absolute_urls(html)
      expect(result).to eq('/product/my-product/')
    end

    it 'converts root URLs' do
      html = 'https://3kshop.vn/about/'
      result = described_class.convert_absolute_urls(html)
      expect(result).to eq('/about/')
    end
  end
end
