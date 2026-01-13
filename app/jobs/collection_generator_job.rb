class CollectionGeneratorJob < ApplicationJob
  queue_as :default

  def perform
    CollectionGeneratorService.call
  rescue StandardError => e
    Rails.logger.error "CollectionGeneratorJob failed: #{e.message}"
    raise
  end
end
