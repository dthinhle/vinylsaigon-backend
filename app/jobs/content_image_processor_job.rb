# Downloads external images from Lexical content, stores them via ActiveStorage, and replaces URLs.
# Processes Lexical JSON format with nested node structures.
# Side effects: Creates ActiveStorage blobs, updates model content field, may fail on network/validation errors.
class ContentImageProcessorJob < ApplicationJob
  include ContentImageProcessorHelper

  queue_as :background
  sidekiq_options retry: 1, dead: true

  attr_reader :blob_url_mappings

  MAX_FILE_SIZE = 5 * 1024 * 1024

  def perform(model_type, model_id, content_hash = nil)
    @blob_url_mappings = {}

    model = model_type.constantize.find(model_id)

    if content_hash && !content_changed?(model, content_hash)
      Rails.logger.info("ContentImageProcessorJob: Skipping #{model_type} #{model_id} - content unchanged")
      return
    end

    Rails.logger.info("ContentImageProcessorJob: Processing images for #{model_type} #{model_id}")

    fields = content_fields_for(model)
    return if fields.empty?

    fields.each do |field|
      content = parse_content(model.send(field))
      next unless content

      images = extract_external_images(content['root'])
      next if images.empty?

      Rails.logger.info("ContentImageProcessorJob: Found #{images.size} external images in #{field}")

      images.each do |image_url|
        next if blob_url_mappings.key?(image_url)

        begin
          blob = download_and_attach_image(image_url, model)
          blob_url_mappings[image_url] = PublicImagePathService.handle(blob) if blob
        rescue SecurityError => e
          Rails.logger.error("ContentImageProcessorJob: Security error for #{image_url}: #{e.message}")
        rescue StandardError => e
          Rails.logger.error("ContentImageProcessorJob: Failed to process image #{image_url}: #{e.message}")
        end
      end
    end

    return if blob_url_mappings.empty?

    update_model_content(model, fields)

    Rails.logger.info("ContentImageProcessorJob: Completed for #{model_type} #{model_id}, processed #{blob_url_mappings.size} images")
  end

  private

  def content_fields_for(model)
    case model
    when Blog
      [:content]
    when Product
      Product::LEXICAL_COLUMNS.map(&:to_sym)
    else
      model.respond_to?(:content) ? [:content] : []
    end
  end

  def content_changed?(model, expected_hash)
    fields = content_fields_for(model)
    content_values = fields.map { |field| model.send(field) }.join
    current_hash = Digest::SHA256.hexdigest(content_values)
    current_hash == expected_hash
  end

  def download_and_attach_image(url, model)
    validate_url_safety(url)

    response, uri = fetch_with_redirects(url)
    content_type = response.headers['content-type']

    return nil unless content_type&.start_with?('image/')

    if response.bytesize > MAX_FILE_SIZE
      Rails.logger.warn("ContentImageProcessorJob: Image too large (#{response.bytesize} bytes) for #{url}")
      return nil
    end

    raw_filename = File.basename(uri.path).presence || "image_#{SecureRandom.hex(8)}.jpg"
    filename = sanitize_filename(raw_filename)

    io = StringIO.new(response)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: filename,
      content_type: content_type
    )

    Rails.logger.info("ContentImageProcessorJob: Attached blob #{blob.id} for #{url}")

    model.content_images.attach(blob)
    Rails.logger.info("ContentImageProcessorJob: Attached content image #{blob.id} for #{model.class.name} #{model.id}")
    blob
  rescue URI::InvalidURIError => e
    Rails.logger.error("ContentImageProcessorJob: Invalid URL #{url}: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.error("ContentImageProcessorJob: Failed to download image #{url}: #{e.message}")
    nil
  end

  def update_model_content(model, fields)
    fields.each do |field|
      content = parse_content(model.send(field))
      next unless content

      updated_content = replace_image_urls(content)
      model.update!(field => updated_content)
    end
  end

  def replace_image_urls(content)
    content = content.deep_dup
    replace_in_node(content['root'])
    content
  end

  def replace_in_node(node)
    return unless node.is_a?(Hash)

    if ['image', 'video'].include?(node['type']) && node['src']
      new_url = blob_url_mappings[node['src']]
      node['src'] = new_url if new_url
    end

    if node['type'] == 'link' && node['url']
      new_url = blob_url_mappings[node['url']]
      node['url'] = new_url if new_url
    end

    if node['children'].is_a?(Array)
      node['children'].each do |child|
        replace_in_node(child)
      end
    end
  end

  def rails_blob_url(blob)
    PublicImagePathService.handle(blob)
  end

  def fetch_with_redirects(url, max_redirects = 3)
    current_url = url
    redirects = 0
    prev_location = nil

    loop do
      response = HTTParty.get(current_url, follow_redirects: false, timeout: 15)
      uri = URI.parse(current_url)

      Rails.logger.info("ContentImageProcessorJob: Fetched #{current_url} - Response: #{response.code}")

      if response.redirection? && response.headers['location']
        location = response.headers['location']

        if prev_location == location
          Rails.logger.warn("ContentImageProcessorJob: Recursive redirect detected: #{location}")
          return [nil, uri]
        end

        if redirects >= max_redirects
          Rails.logger.warn("ContentImageProcessorJob: Too many redirects (max: #{max_redirects}) for #{url}")
          return [nil, uri]
        end

        prev_location = location
        redirects += 1

        current_url = location
      else
        return [response, uri]
      end
    end
  end
end
