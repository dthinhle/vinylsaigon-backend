class ImagePathService
  include Rails.application.routes.url_helpers

  attr_reader :image

  def initialize(image)
    @image = image
  end

  def path
    return nil unless image

    PublicImagePathService.handle(image.blob)
  end

  def thumbnail_path
    return nil unless image

    processed_variant = image.variant(:thumbnail).processed
    PublicImagePathService.handle(processed_variant.image.blob)
  end
end
