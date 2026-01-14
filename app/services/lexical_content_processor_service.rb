class LexicalContentProcessorService
  def self.process_for_export(content)
    return content if content.blank?

    parsed = JSON.parse(content) rescue content
    return content unless parsed.is_a?(Hash) && parsed['root']

    mark_relative_links(parsed['root'])
    parsed.to_json
  end

  def self.process_for_import(content, product)
    return content if content.blank?

    parsed = JSON.parse(content) rescue content
    return content unless parsed.is_a?(Hash) && parsed['root']

    clean_relative_links(parsed['root'])
    schedule_external_media_download(product) if has_external_media?(parsed['root'])

    parsed.to_json
  end

  private

  def self.mark_relative_links(node)
    return unless node.is_a?(Hash)

    if node['type'] == 'link' && node['url']
      url = node['url']
      if url.start_with?('/')
        node['relative_path'] = true
      end
    end

    if node['children'].is_a?(Array)
      node['children'].each { |child| mark_relative_links(child) }
    end
  end

  def self.clean_relative_links(node)
    return unless node.is_a?(Hash)

    if node['type'] == 'link' && node['relative_path'] == true && node['url']
      url = node['url']
      link_text = extract_link_text(node)
      should_convert = false

      if url.match?(%r{^/thuong-hieu/(.+)$})
        slug = Regexp.last_match(1)
        should_convert = true unless Brand.exists?(slug: slug)
      elsif url.match?(%r{^/danh-muc/(.+)$})
        slug = Regexp.last_match(1)
        should_convert = true unless Category.exists?(slug: slug)
      elsif url.match?(%r{^/bo-suu-tap/(.+)$})
        slug = Regexp.last_match(1)
        should_convert = true unless ProductCollection.exists?(slug: slug)
      elsif url.match?(%r{^/[^/]+$})
        slug = url[1..]
        should_convert = true unless Product.exists?(slug: slug)
      end

      if should_convert
        convert_to_text_node(node, link_text)
      else
        node.delete('relative_path')
      end
    end

    if node['children'].is_a?(Array)
      node['children'].each { |child| clean_relative_links(child) }
    end
  end

  def self.extract_link_text(node)
    return '' unless node['children'].is_a?(Array)

    node['children'].map do |child|
      if child['type'] == 'text'
        child['text'] || ''
      else
        extract_link_text(child)
      end
    end.join
  end

  def self.convert_to_text_node(node, text)
    format = node['format'] || 0
    style = node['style'] || ''

    node.clear
    node['text'] = text
    node['type'] = 'text'
    node['format'] = format
    node['style'] = style
    node['direction'] = nil
    node['textStyle'] = ''
    node['detail'] = 0
  end

  def self.has_external_media?(node)
    return false unless node.is_a?(Hash)

    backend_host = BACKEND_HOST

    if ['image', 'video'].include?(node['type']) && node['src']
      src = node['src']
      return true if src.start_with?('http') && !src.start_with?(backend_host)
    end

    if node['type'] == 'link' && node['url']
      url = node['url']
      return true if url.start_with?('http') && !url.start_with?(backend_host)
    end

    if node['children'].is_a?(Array)
      return true if node['children'].any? { |child| has_external_media?(child) }
    end

    false
  end

  def self.schedule_external_media_download(product)
    ContentImageProcessorJob.perform_later('Product', product.id) if product.id
  end
end
