# Detects external images in Lexical content and enqueues a background job to download and attach them.
# Supports Blog (content field) and Product (description/short_description fields).
# Called automatically via model callbacks when content changes.
class ContentImageProcessorService
  include ContentImageProcessorHelper

  def self.call(model)
    new(model).call
  end

  def initialize(model)
    @model = model
  end

  def call
    return unless should_process?

    content_hash = generate_content_hash
    ContentImageProcessorJob.perform_later(@model.class.name, @model.id, content_hash)
    Rails.logger.info("ContentImageProcessorService: Queued job for #{@model.class.name} #{@model.id} with hash #{content_hash}")
  end

  private

  def should_process?
    return false unless @model.id

    fields = content_fields
    return false if fields.empty?

    fields.any? do |field|
      content_value = @model.send(field)
      next false if content_value.blank?

      parsed = parse_content(content_value)
      next false unless parsed

      has_external_images?(parsed['root'])
    end
  end

  def content_fields
    case @model
    when Blog
      [:content]
    when Product
      [:description, :short_description]
    else
      @model.respond_to?(:content) ? [:content] : []
    end
  end

  def generate_content_hash
    fields = content_fields
    content_values = fields.map { |field| @model.send(field) }.join
    Digest::SHA256.hexdigest(content_values)
  end
end
