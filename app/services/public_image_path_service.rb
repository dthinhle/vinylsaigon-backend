class PublicImagePathService
  def self.handle(image)
    return nil unless image.is_a?(ActiveStorage::VariantWithRecord) || image.is_a?(ActiveStorage::Blob)

    return Rails.application.routes.url_helpers.rails_blob_url(image) if Rails.env.development? || Rails.env.test?

    "#{ENV['AWS_S3_PUBLIC_ENDPOINT']}/#{image.key}"
  end
end
