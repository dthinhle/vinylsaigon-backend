module ContentImageProcessorHelper
  def parse_content(content)
    if content.is_a?(String)
      JSON.parse(content)
    else
      content
    end
  rescue JSON::ParserError => e
    Rails.logger.error("ContentImageProcessorHelper: Failed to parse content: #{e.message}")
    nil
  end

  def external_image?(url)
    return false if url.blank?
    return false if url.start_with?('/rails/active_storage/')
    return false if url.start_with?('/assets/')

    url.start_with?('http://', 'https://')
  end

  def has_external_images?(node)
    queue = [node]
    while queue.any?
      current = queue.shift
      next unless current.is_a?(Hash)

      if current['type'] == 'image'
        src = current['src']
        return true if src && external_image?(src)
      end

      if current['children'].is_a?(Array)
        queue.concat(current['children'])
      end
    end
    false
  end

  def extract_external_images(root)
    images = []
    queue = [root]
    while queue.any?
      node = queue.shift
      next unless node.is_a?(Hash)

      if node['type'] == 'image'
        src = node['src']
        images << src if src && external_image?(src)
      end

      if node['children'].is_a?(Array)
        queue.concat(node['children'])
      end
    end
    images
  end

  def validate_url_safety(url)
    uri = URI.parse(url)

    unless %w[http https].include?(uri.scheme)
      raise SecurityError, "Invalid URL scheme: #{uri.scheme}"
    end

    host = uri.host
    return if host.nil?

    blocked_hosts = %w[
      localhost
      127.0.0.1
      169.254.169.254
      ::1
      0.0.0.0
    ]

    if blocked_hosts.any? { |blocked| host.downcase == blocked }
      raise SecurityError, "Access to #{host} is not allowed"
    end

    begin
      resolved_ip = Resolv.getaddress(host)
      addr = IPAddr.new(resolved_ip)

      private_ranges = [
        IPAddr.new('10.0.0.0/8'),
        IPAddr.new('172.16.0.0/12'),
        IPAddr.new('192.168.0.0/16'),
        IPAddr.new('127.0.0.0/8'),
        IPAddr.new('169.254.0.0/16'),
        IPAddr.new('::1/128'),
        IPAddr.new('fc00::/7'),
      ]

      if private_ranges.any? { |range| range.include?(addr) }
        raise SecurityError, "Access to private IP range is not allowed: #{resolved_ip}"
      end
    rescue Resolv::ResolvError => e
      raise SecurityError, "Unable to resolve hostname: #{e.message}"
    end
  rescue URI::InvalidURIError => e
    raise SecurityError, "Invalid URI: #{e.message}"
  end

  def sanitize_filename(filename)
    filename.gsub(/[^0-9A-Za-z.\-_]/, '_').gsub(/\.\.+/, '.').slice(0, 255)
  end
end
